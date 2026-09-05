# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from unicontext import BUDGET_MAX, BUDGET_MIN, abi_version, valid_budget, version


def test_version_matches_the_manifest():
    assert version() == "1.0.0"
    assert abi_version() == 1


def test_budget_bounds_come_from_the_header():
    assert (BUDGET_MIN, BUDGET_MAX) == (128, 32768)


def test_budget_contract_matches_the_bounds():
    assert valid_budget(BUDGET_MIN)
    assert valid_budget(BUDGET_MAX)
    assert not valid_budget(BUDGET_MIN - 1)
    assert not valid_budget(BUDGET_MAX + 1)
    assert not valid_budget(0)


def test_out_of_c_range_is_answered_not_raised():
    assert not valid_budget(2**63)
    assert not valid_budget(-(2**63))
