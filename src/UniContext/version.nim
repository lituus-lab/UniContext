## SPDX-License-Identifier: Apache-2.0
## Copyright 2026 lituus-lab
const UniContextVersion* = "1.0.0"
  ## Checked against the manifest, the header, the C ABI and the wheel by
  ## `tests/test_version.nim`.
  ##
  ## Its own module rather than the umbrella's: `cli` needs only the version,
  ## and importing `UniContext` for it made `nimble build` fail on Windows,
  ## where nimble builds from a copied tree the umbrella is not on the path of.
