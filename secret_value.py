"""A class that holds a value you can set and use, but never see.

The trick: the value is never stored as an attribute on the object.
Instead it's captured inside closures created in __init__. That means:

  * ``obj.val`` / ``obj.value`` / ``obj.__dict__`` -> nothing there, AttributeError
  * ``print(obj)`` -> just shows a placeholder
  * but methods can still *use* the value (compare it, test it, etc.)
"""


class SecretValue:
    def __init__(self, value):
        # The value lives only inside these lambdas' closure cells,
        # never on self. There is no attribute to grab.
        self._equals = lambda other: value == other
        self._less_than = lambda other: value < other
        self._greater_than = lambda other: value > other
        self._satisfies = lambda test: bool(test(value))

    # --- printing never reveals it -------------------------------------
    def __repr__(self):
        return "SecretValue(<hidden>)"

    __str__ = __repr__

    def __format__(self, spec):
        return "<hidden>"

    # --- but you can still USE it --------------------------------------
    def __eq__(self, other):
        return self._equals(other)

    def __lt__(self, other):
        return self._less_than(other)

    def __gt__(self, other):
        return self._greater_than(other)

    def check(self, test):
        """Run a True/False test against the value, e.g. s.check(lambda v: v > 10)."""
        return self._satisfies(test)

    # --- and you can't guess an attribute name to reach it -------------
    def __getattr__(self, name):
        raise AttributeError(
            f"nice try - {type(self).__name__} has no attribute {name!r}"
        )


if __name__ == "__main__":
    s = SecretValue(42)

    # printing doesn't reveal it
    print(s)                      # SecretValue(<hidden>)
    print(f"the value is {s}")    # the value is <hidden>

    # but you can still use it
    print(s == 42)                # True
    print(s == 41)                # False
    print(s > 10)                 # True
    print(s < 10)                 # False
    print(s.check(lambda v: v % 2 == 0))  # True (it's even)

    # and you can't just grab it
    try:
        print(s.val)
    except AttributeError as e:
        print(e)                  # nice try - SecretValue has no attribute 'val'

    print(s.__dict__.keys())      # only the lambdas, no raw value stored
