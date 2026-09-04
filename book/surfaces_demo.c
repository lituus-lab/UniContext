/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* Run by book/surfaces.nim during the book build; its output is the page's. */
#include <stdio.h>
#include "UniContext.h"

int main(void) {
  printf("unicontext_version()            = %s\n", unicontext_version());
  printf("unicontext_fibonacci(10)        = %lld\n", unicontext_fibonacci(10));
  printf("unicontext_fibonacci(-1)        = %lld   (clamped, not an error)\n",
         unicontext_fibonacci(-1));
  printf("unicontext_fibonacci(200)       = %lld   (clamped to n = %d)\n",
         unicontext_fibonacci(200), UNICONTEXT_FIB_MAX_N);
  return 0;
}
