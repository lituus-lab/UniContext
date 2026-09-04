// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include "UniContext.h"

int main(void) {
  printf("UniContext %s\n", unicontext_version());
  int ns[] = {0, 1, 10, 20, 50, 90, UNICONTEXT_FIB_MAX_N};
  for (size_t i = 0; i < sizeof(ns) / sizeof(ns[0]); i++)
    printf("fib(%d) = %lld\n", ns[i], unicontext_fibonacci(ns[i]));
  return 0;
}
