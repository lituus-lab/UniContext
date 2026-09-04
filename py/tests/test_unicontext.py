## SPDX-License-Identifier: Apache-2.0
from unicontext import valid_budget, version

def test_budget_contract():
    assert version() == "1.0.0"
    assert valid_budget(128)
    assert valid_budget(32768)
    assert not valid_budget(0)
