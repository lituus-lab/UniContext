# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Cython binding over the UniContext C ABI."""

cdef extern from "UniContext.h":
    const char *unicontext_version()
    int unicontext_abi_version()
    int unicontext_valid_budget(int tokens)
    # Taken from the header rather than restated here: one copy fewer to
    # drift, and the bounds Python reports are the ones the library enforces.
    int UNICONTEXT_BUDGET_MIN
    int UNICONTEXT_BUDGET_MAX


BUDGET_MIN = UNICONTEXT_BUDGET_MIN
BUDGET_MAX = UNICONTEXT_BUDGET_MAX


def version():
    """The library version, read from the linked library."""
    return unicontext_version().decode("ascii")


def abi_version():
    """The C ABI generation the extension was built against."""
    return unicontext_abi_version()


def valid_budget(int tokens):
    """True when tokens is an acceptable context-packet budget."""
    return unicontext_valid_budget(tokens) != 0
