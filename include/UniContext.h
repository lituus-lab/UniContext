/* SPDX-License-Identifier: Apache-2.0 */
#ifndef UNICONTEXT_H
#define UNICONTEXT_H
#ifdef __cplusplus
extern "C" {
#endif
const char *unicontext_version(void);
int unicontext_abi_version(void);
int unicontext_valid_budget(int tokens);
#ifdef __cplusplus
}
#endif
#endif
