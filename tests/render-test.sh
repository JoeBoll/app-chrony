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
exit "${fail}"
