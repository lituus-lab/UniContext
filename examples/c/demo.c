// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
// What a C caller can do with UniContext without linking a JSON parser:
// identify the library it loaded, and screen a budget before asking for a
// packet over the MCP surface.
#include <stdio.h>
#include "UniContext.h"

int main(void) {
  printf("UniContext %s, C ABI generation %d\n", unicontext_version(),
         unicontext_abi_version());
  printf("accepted budgets: %d to %d tokens\n\n", UNICONTEXT_BUDGET_MIN,
         UNICONTEXT_BUDGET_MAX);

  const int budgets[] = {0, UNICONTEXT_BUDGET_MIN - 1, UNICONTEXT_BUDGET_MIN,
                         4096, UNICONTEXT_BUDGET_MAX,
                         UNICONTEXT_BUDGET_MAX + 1};
  for (size_t i = 0; i < sizeof(budgets) / sizeof(budgets[0]); i++) {
    printf("%8d  %s\n", budgets[i],
           unicontext_valid_budget(budgets[i]) ? "accepted" : "refused");
  }
  return 0;
}
