/* SPDX-License-Identifier: Apache-2.0 */
#include "UniContext.h"
#include <assert.h>
int main(void) {
  assert(unicontext_abi_version() == 1);
  assert(unicontext_valid_budget(128) == 1);
  assert(unicontext_valid_budget(0) == 0);
  return 0;
}
