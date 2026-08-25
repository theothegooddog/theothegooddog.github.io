"""A class that holds a value you can set and use, but never see.

The value is never stored as an attribute — it lives only inside a single
closure (the "vault") created in __init__. On top of that, this version
adds extra safeguards:

  1. __slots__            -> the object has NO __dict__ at all, so there is
                             nothing to snoop in and no new attributes can
                             be attached.
  2. frozen instance      -> after __init__, setting or deleting ANY
                             attribute raises (you can't swap the vault out
                             for a leaky one).
  3. hidden vault         -> even the internal '_vault' attribute is blocked
                             from normal access; s._vault raises.
  4. no pickling/copying  -> pickle.dumps, copy.copy and copy.deepcopy all
                             refuse, so the value can't be serialized out.
  5. no subclassing       -> you can't subclass it to add a leaky __repr__.
  6. password reveal      -> reveal(password) returns the value only with
                             the password set at construction, and the vault
                             permanently locks itself after 3 wrong guesses.
"""

import hmac


class SecretValue:
    __slots__ = ("_vault",)          # no __dict__, no attaching new attributes

    MAX_ATTEMPTS = 3

    def __init__(self, value, password=None):
        state = {"attempts": 0, "locked": False}

        def vault(op, arg=None):
            if state["locked"]:
                raise PermissionError("vault is permanently locked")
            if op == "eq":
                return value == arg
            if op == "lt":
                return value < arg
            if op == "gt":
                return value > arg
            if op == "test":
                return bool(arg(value))
            if op == "reveal":
                if password is None:
                    raise PermissionError("this vault is sealed - no password was set")
                if hmac.compare_digest(str(arg), str(password)):
                    state["attempts"] = 0
                    return value
                state["attempts"] += 1
                if state["attempts"] >= SecretValue.MAX_ATTEMPTS:
                    state["locked"] = True
                    raise PermissionError("too many wrong passwords - vault locked forever")
                remaining = SecretValue.MAX_ATTEMPTS - state["attempts"]
                raise PermissionError(f"wrong password ({remaining} attempts left)")
            raise ValueError(f"unknown vault operation {op!r}")

        object.__setattr__(self, "_vault", vault)

    # --- internal helper: the only sanctioned door into the vault -------
    def _use(self, op, arg=None):
        return object.__getattribute__(self, "_vault")(op, arg)

    # --- printing never reveals it ---------------------------------------
    def __repr__(self):
        return "SecretValue(<hidden>)"

    __str__ = __repr__

    def __format__(self, spec):
        return "<hidden>"

    # --- but you can still USE it -----------------------------------------
    def __eq__(self, other):
        return self._use("eq", other)

    def __lt__(self, other):
        return self._use("lt", other)

    def __gt__(self, other):
        return self._use("gt", other)

    def check(self, test):
        """Run a True/False test against the value, e.g. s.check(lambda v: v > 10)."""
        return self._use("test", test)

    def reveal(self, password):
        """Return the value, but only with the right password. 3 strikes and
        the vault locks forever."""
        return self._use("reveal", password)

    # --- safeguard: even '_vault' can't be reached normally ---------------
    def __getattribute__(self, name):
        if name == "_vault":
            raise AttributeError("nice try - the vault is off limits")
        return object.__getattribute__(self, name)

    def __getattr__(self, name):
        if name == "_vault":
            raise AttributeError("nice try - the vault is off limits")
        raise AttributeError(
            f"nice try - {type(self).__name__} has no attribute {name!r}"
        )

    # --- safeguard: frozen after construction -----------------------------
    def __setattr__(self, name, value):
        raise AttributeError("SecretValue is frozen - attributes can't be set")

    def __delattr__(self, name):
        raise AttributeError("SecretValue is frozen - attributes can't be deleted")

    # --- safeguard: can't pickle/copy the value out ------------------------
    def __reduce_ex__(self, protocol):
        raise TypeError("SecretValue refuses to be pickled or copied")

    __reduce__ = __reduce_ex__

    # --- safeguard: can't subclass it to add a leaky repr ------------------
    def __init_subclass__(cls, **kwargs):
        raise TypeError("SecretValue can't be subclassed")

    # --- keep dir() clean of internals -------------------------------------
    def __dir__(self):
        return ["check", "reveal"]


if __name__ == "__main__":
    import copy
    import pickle

    s = SecretValue(42, password="hunter2")

    # printing doesn't reveal it
    print(s)                                # SecretValue(<hidden>)
    print(f"the value is {s}")              # the value is <hidden>

    # but you can still use it
    print(s == 42)                          # True
    print(s > 10)                           # True
    print(s.check(lambda v: v % 2 == 0))    # True (it's even)

    # attack 1: grab an attribute
    try:
        s.val
    except AttributeError as e:
        print(e)                            # nice try - ... no attribute 'val'

    # attack 2: go for the vault directly
    try:
        s._vault
    except AttributeError as e:
        print(e)                            # nice try - the vault is off limits

    # attack 3: snoop the instance dict
    try:
        vars(s)
    except TypeError as e:
        print("no __dict__ to snoop:", e)

    # attack 4: swap in a leaky method
    try:
        s.check = lambda t: "gotcha"
    except AttributeError as e:
        print(e)                            # SecretValue is frozen ...

    # attack 5: smuggle it out via pickle or copy
    for attempt in (lambda: pickle.dumps(s), lambda: copy.deepcopy(s)):
        try:
            attempt()
        except TypeError as e:
            print(e)                        # refuses to be pickled or copied

    # legit access: password reveal, with lockout
    print(s.reveal("hunter2"))              # 42
    t = SecretValue("shh", password="pw")
    for guess in ("a", "b", "c", "pw"):
        try:
            t.reveal(guess)
        except PermissionError as e:
            print(e)                        # ...2 left, 1 left, locked forever
    try:
        t == "shh"                          # even normal use is dead now
    except PermissionError as e:
        print(e)                            # vault is permanently locked
