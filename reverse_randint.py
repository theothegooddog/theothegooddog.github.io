#!/usr/bin/env python3
"""Reverse Python's ``random.randint`` by cloning the Mersenne Twister.

Python's :mod:`random` module is built on the MT19937 Mersenne Twister, which
is a *deterministic* generator with no cryptographic strength. Its output is
produced by taking 32-bit words from an internal 624-word state and passing
each through an invertible "tempering" function.

Because tempering is invertible, an observer who sees 624 consecutive raw
32-bit outputs can "untemper" them to reconstruct the entire internal state,
build an identical generator, and then reproduce every value the original will
ever produce -- including future ``random.randint`` results. That is what this
module does.

The catch for ``randint`` specifically: ``random.randint(a, b)`` does not emit
clean, aligned 32-bit words. Under the hood it uses ``_randbelow(n)`` ->
``getrandbits(k)`` where ``n = b - a + 1`` and ``k = n.bit_length()``, and for
non-power-of-two ranges it uses rejection sampling (discarding some words
entirely). There is no ``randint`` range that yields exactly one full 32-bit
word per call with no discarded bits. So to recover the state we observe the
generator's raw output via ``getrandbits(32)`` -- one tempered word per call.

That is not a limitation of the attack: ``randint`` draws from the very same
32-bit MT19937 stream. Once we have cloned the state from 624 raw words, our
clone reproduces that stream exactly, and therefore predicts every subsequent
``randint`` result over *any* range.

Run this file directly for a demonstration.
"""

from __future__ import annotations

import random

N = 624  # number of 32-bit words in the MT19937 state


def _undo_right_shift_xor(value: int, shift: int) -> int:
    """Invert ``value ^ (value >> shift)`` for a 32-bit integer."""
    result = value
    for _ in range(32 // shift + 1):
        result = value ^ (result >> shift)
    return result & 0xFFFFFFFF


def _undo_left_shift_xor_and(value: int, shift: int, mask: int) -> int:
    """Invert ``value ^ ((value << shift) & mask)`` for a 32-bit integer."""
    result = value
    for _ in range(32 // shift + 1):
        result = value ^ ((result << shift) & mask)
    return result & 0xFFFFFFFF


def untemper(y: int) -> int:
    """Reverse MT19937's tempering transform to recover a state word.

    The tempering applied by MT19937 (with the standard constants) is::

        y ^= y >> 11
        y ^= (y << 7)  & 0x9D2C5680
        y ^= (y << 15) & 0xEFC60000
        y ^= y >> 18

    Each step is a bijection on 32-bit words, so we undo them in reverse order.
    """
    y = _undo_right_shift_xor(y, 18)
    y = _undo_left_shift_xor_and(y, 15, 0xEFC60000)
    y = _undo_left_shift_xor_and(y, 7, 0x9D2C5680)
    y = _undo_right_shift_xor(y, 11)
    return y


def clone_from_words(words: list[int]) -> random.Random:
    """Build a ``random.Random`` clone from 624 consecutive 32-bit outputs.

    ``words`` must be 624 raw, aligned 32-bit outputs of the target generator,
    e.g. from ``getrandbits(32)``.
    """
    if len(words) != N:
        raise ValueError(f"need exactly {N} consecutive 32-bit words, got {len(words)}")

    state = tuple(untemper(w) for w in words)

    clone = random.Random()
    # CPython's getstate() returns (version, tuple_of_625_ints, gauss_next).
    # The 625-int tuple is the 624 state words plus the current index; setting
    # the index to 624 forces a regeneration on the next draw, which puts the
    # clone exactly where the target is after emitting `words`.
    clone.setstate((3, state + (N,), None))
    return clone


def _demo() -> None:
    print("=" * 64)
    print("Reversing random.randint via MT19937 state recovery")
    print("=" * 64)

    # The "unknown" target generator. Seed is secret to the attacker.
    target = random.Random()

    # 1. Observe 624 raw 32-bit outputs from the target. getrandbits(32) emits
    #    exactly one tempered MT19937 word per call -- the clean signal we need.
    observed = [target.getrandbits(32) for _ in range(N)]
    print(f"\nObserved {len(observed)} outputs of getrandbits(32).")
    print(f"  first: {observed[0]}")
    print(f"  last:  {observed[-1]}")

    # 2. Reconstruct the internal state and clone the generator.
    clone = clone_from_words(observed)
    print("\nRecovered internal state and built a clone.")

    # 3. Predict the target's future randint outputs over a large range.
    print("\nPredicting the next 5 randint(0, 10**9) calls:")
    ok = True
    for i in range(5):
        predicted = clone.randint(0, 10**9)
        actual = target.randint(0, 10**9)
        match = predicted == actual
        ok = ok and match
        print(f"  [{i}] predicted={predicted:<12} actual={actual:<12} {'OK' if match else 'MISMATCH'}")

    # 4. Prediction works for any other range too, since the clone reproduces
    #    the exact same underlying MT19937 stream.
    print("\nPredicting the next 5 dice rolls, randint(1, 6):")
    for i in range(5):
        predicted = clone.randint(1, 6)
        actual = target.randint(1, 6)
        match = predicted == actual
        ok = ok and match
        print(f"  [{i}] predicted={predicted} actual={actual} {'OK' if match else 'MISMATCH'}")

    print("\n" + ("All predictions matched -- randint reversed." if ok else "Some predictions failed."))


if __name__ == "__main__":
    _demo()
