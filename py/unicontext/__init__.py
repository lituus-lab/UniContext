## SPDX-License-Identifier: Apache-2.0
"""Small ctypes binding for the UniContext C ABI."""
from ctypes import CDLL, c_int
from pathlib import Path
import sys

_name = "libUniContext.dylib" if sys.platform == "darwin" else "libUniContext.so"
_library = CDLL(str(Path(__file__).with_name(_name)))
_library.unicontext_valid_budget.argtypes = [c_int]
_library.unicontext_valid_budget.restype = c_int

def version() -> str:
    return "1.0.0"

def valid_budget(tokens: int) -> bool:
    return bool(_library.unicontext_valid_budget(tokens))
