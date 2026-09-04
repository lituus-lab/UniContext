# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import pytest
import unicontext


def test_version():
    assert unicontext.version() == "0.1.0"
    assert unicontext.__version__ == "0.1.0"


@pytest.mark.parametrize("n,want", [
    (0, 0), (1, 1), (2, 1), (10, 55), (20, 6765),
    (50, 12586269025),
])
def test_known_values(n, want):
    assert unicontext.fibonacci(n) == want


def test_the_bound_comes_from_the_c_header():
    # Not a literal: the binding reads UNICONTEXT_FIB_MAX_N, so the value a
    # caller is checked against is the one the C ABI clamps to.
    assert unicontext.FIB_MAX_N == 92
    assert unicontext.fibonacci(unicontext.FIB_MAX_N) == 7540113804746346429


def test_out_of_range_raises():
    with pytest.raises(ValueError):
        unicontext.fibonacci(-1)
    with pytest.raises(ValueError):
        unicontext.fibonacci(unicontext.FIB_MAX_N + 1)


def test_non_int_raises():
    with pytest.raises(TypeError):
        unicontext.fibonacci(10.0)
