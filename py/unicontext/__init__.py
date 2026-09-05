# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Python binding for the UniContext C ABI."""
from ._core import BUDGET_MAX, BUDGET_MIN, abi_version, valid_budget, version

#: Read from the linked library, so it cannot drift from what is installed.
__version__ = version()

__all__ = ["BUDGET_MAX", "BUDGET_MIN", "__version__", "abi_version",
           "valid_budget", "version"]
