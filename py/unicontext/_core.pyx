# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
cdef extern from "UniContext.h":
    const char *unicontext_version()
    long long unicontext_fibonacci(int n)
    # The domain bound comes from the header rather than being restated here:
    # one copy fewer to drift, and the Python check enforces exactly what the
    # C ABI clamps to.
    int UNICONTEXT_FIB_MAX_N


FIB_MAX_N = UNICONTEXT_FIB_MAX_N


def fibonacci(int n):
    """Raw C call (no domain check). Use unicontext.fibonacci."""
    return unicontext_fibonacci(n)


def version():
    return unicontext_version()
