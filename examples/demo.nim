## SPDX-License-Identifier: Apache-2.0
import UniContext/domain/types
import UniContext/context/builder

when isMainModule:
  let packet = buildContextPacket("demo", @[], 128)
  echo packet.rendered
