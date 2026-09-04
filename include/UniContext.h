/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* Kept in sync by hand with src/UniContext/c_api.nim; tests/c links this
   header against the built library, and tests/test_version.nim checks the
   version and the budget bounds against the manifest and the Nim constants. */
#ifndef UNICONTEXT_H
#define UNICONTEXT_H

#define UNICONTEXT_VERSION_MAJOR 1
#define UNICONTEXT_VERSION_MINOR 0
#define UNICONTEXT_VERSION_PATCH 0
#define UNICONTEXT_VERSION "1.0.0"

/* Bounds of a context packet's token budget, mirroring
   UniContext/domain/types. A C caller needs the literals to size its own
   input checks, so they are stated here as well as returned by
   unicontext_valid_budget. */
#define UNICONTEXT_BUDGET_MIN 128
#define UNICONTEXT_BUDGET_MAX 32768

#ifdef __cplusplus
extern "C" {
#endif

/* The library version, "MAJOR.MINOR.PATCH". Static storage; do not free. */
const char *unicontext_version(void);

/* The ABI generation. Bumped only by a breaking change to this header. */
int unicontext_abi_version(void);

/* 1 when tokens is an acceptable packet budget, 0 otherwise. Never raises:
   an out-of-range value is answered, not rejected. */
int unicontext_valid_budget(int tokens);

#ifdef __cplusplus
}
#endif
#endif
