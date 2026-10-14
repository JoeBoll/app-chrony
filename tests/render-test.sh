#!/usr/bin/env bash
# Render every tests/options-*.json and check chronyd accepts the result.
# Usage: tests/render-test.sh   (needs jq and chronyd on PATH)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
render="${here}/../chrony/rootfs/usr/bin/chrony-render-config"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
fail=0
for f in "${here}"/options-*.json; do
  n=$(basename "${f}" .json)
  "${render}" "${f}" "${tmp}/${n}.conf" "${tmp}/${n}.keys" 2>"${tmp}/${n}.err"
  [[ "$(stat -c %a "${tmp}/${n}.keys")" == 600 ]] || { echo "FAIL ${n}: keyfile mode"; fail=1; }
  if grep -q 'secret\|HEX:' "${tmp}/${n}.conf"; then echo "FAIL ${n}: secret in conf"; fail=1; fi
  if grep -qE '^peer .*iburst' "${tmp}/${n}.conf"; then echo "FAIL ${n}: iburst on peer"; fail=1; fi
  if chronyd -p -f "${tmp}/${n}.conf" >/dev/null; then echo "ok   ${n}"; else echo "FAIL ${n}: chronyd -p"; fail=1; fi
done
echo '{"mode":"none","peers":[{"address":"1.2.3.4; x"}]}' > "${tmp}/bad.json"
if "${render}" "${tmp}/bad.json" "${tmp}/b.conf" "${tmp}/b.keys" 2>/dev/null; then
  echo "FAIL: bad address accepted"; fail=1
elif [[ -e "${tmp}/b.conf" ]]; then echo "FAIL: partial conf left"; fail=1
else echo "ok   rejects bad address"; fi
if grep -qx 'peer 192.0.2.10 key 1 xleave minpoll -6 maxpoll -6 filter 7' "${tmp}/options-subsecond-peer.conf"; then
  echo "ok   sub-second peer line"; else echo "FAIL sub-second peer line"; fail=1; fi
for bad in '{"minpoll":-8}' '{"minpoll":2,"maxpoll":1}' '{"filter":0}'; do
  jq -n --argjson b "${bad}" '{mode:"none",peers:[{address:"192.0.2.1"}+$b]}' > "${tmp}/bad2.json"
  if "${render}" "${tmp}/bad2.json" "${tmp}/c.conf" "${tmp}/c.keys" 2>/dev/null; then
    echo "FAIL accepted ${bad}"; fail=1; else echo "ok   rejects ${bad}"; fi
done
exit "${fail}"
