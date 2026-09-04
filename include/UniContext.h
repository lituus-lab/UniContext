// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#ifndef UNICONTEXT_H
#define UNICONTEXT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNICONTEXT_VERSION_MAJOR 0
#define UNICONTEXT_VERSION_MINOR 1
#define UNICONTEXT_VERSION_PATCH 0
#define UNICONTEXT_VERSION "0.1.0"

#define UNICONTEXT_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNICONTEXT_VERSION_MAJOR > (ma)) || \
   (UNICONTEXT_VERSION_MAJOR == (ma) && UNICONTEXT_VERSION_MINOR > (mi)) || \
   (UNICONTEXT_VERSION_MAJOR == (ma) && UNICONTEXT_VERSION_MINOR == (mi) && \
    UNICONTEXT_VERSION_PATCH >= (pa)))

/* Largest n with unicontext_fibonacci(n) fitting in long long (int64). */
#define UNICONTEXT_FIB_MAX_N 92

/* Static version string; do not free. */
const char *unicontext_version(void);

/* fibonacci(n), n clamped to [0, UNICONTEXT_FIB_MAX_N].
 * n < 0 -> 0; n > UNICONTEXT_FIB_MAX_N -> fibonacci(UNICONTEXT_FIB_MAX_N).
 * Never raises. Single-threaded, reentrant. */
long long unicontext_fibonacci(int n);

#ifdef __cplusplus
}
#endif

#endif /* UNICONTEXT_H */
