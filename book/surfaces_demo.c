/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* Compiled and run by the Surfaces chapter, not transcribed into it. */
#include <stdio.h>
#include "UniContext.h"

int main(void) {
  printf("version %s, ABI generation %d\n", unicontext_version(),
         unicontext_abi_version());
  const int budgets[] = {0, UNICONTEXT_BUDGET_MIN, UNICONTEXT_BUDGET_MAX + 1};
  for (size_t i = 0; i < sizeof(budgets) / sizeof(budgets[0]); i++)
    printf("%6d -> %d\n", budgets[i], unicontext_valid_budget(budgets[i]));
  return 0;
}
