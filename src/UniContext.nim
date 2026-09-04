## SPDX-License-Identifier: Apache-2.0
## Copyright 2026 lituus-lab
import UniContext/context/builder
import UniContext/database/store
import UniContext/domain/types
import UniContext/index/indexer
import UniContext/memory/writer
import UniContext/protocol/mcp_server
import UniContext/text/markdown
import UniContext/workspace/[git_state, manifest]

export builder, git_state, indexer, manifest, markdown, mcp_server, store,
  types, writer

const UniContextVersion* = "1.0.0"
  ## Checked against the manifest, the header, the C ABI and the wheel by
  ## `tests/test_version.nim`.
