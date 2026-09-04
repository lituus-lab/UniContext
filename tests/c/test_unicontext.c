// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include "UniContext.h"

#include <stdio.h>
#include <string.h>

static int failures = 0;

static void check(int condition, const char *message) {
  if (condition) {
    printf("ok   %s\n", message);
  } else {
    printf("FAIL %s\n", message);
    failures++;
  }
}

int main(void) {
  check(unicontext_abi_version() == 1, "the ABI generation is 1");

  const char *version = unicontext_version();
  check(version != NULL, "the version is returned");
  check(version != NULL && strcmp(version, UNICONTEXT_VERSION) == 0,
        "the library agrees with the header's version string");

  /* The bounds are inclusive, and one step outside each is refused. */
  check(unicontext_valid_budget(UNICONTEXT_BUDGET_MIN) == 1,
        "the smallest budget is accepted");
  check(unicontext_valid_budget(UNICONTEXT_BUDGET_MAX) == 1,
        "the largest budget is accepted");
  check(unicontext_valid_budget(UNICONTEXT_BUDGET_MIN - 1) == 0,
        "one below the smallest is refused");
  check(unicontext_valid_budget(UNICONTEXT_BUDGET_MAX + 1) == 0,
        "one above the largest is refused");

  /* The ABI never raises: extreme input is answered, not rejected. */
  check(unicontext_valid_budget(0) == 0, "zero is refused");
  check(unicontext_valid_budget(-2147483647 - 1) == 0, "INT_MIN is refused");
  check(unicontext_valid_budget(2147483647) == 0, "INT_MAX is refused");

  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  printf("all checks passed\n");
  return 0;
}
