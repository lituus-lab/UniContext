# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## `src` on the path for every compilation in this repository.
##
## The library's own modules import each other as `UniContext/<module>`, which
## resolves from the importing file's directory only for a file sitting in
## `src` itself. `src/UniContext/cli.nim` does not, and `nimble build` compiles
## it without the `--path:src` the tasks pass -- so the CLI built here and
## failed there.
switch("path", "src")
