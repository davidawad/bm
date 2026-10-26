#!/bin/sh
# Renders docs/sample/output.txt to docs/showcase/sample.png with headless Chrome.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
{
  printf '<html><body style="margin:0;background:#1e1e2e"><pre style="margin:0;padding:20px;color:#cdd6f4;font:14px/1.45 Menlo,monospace">'
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' "$here/../sample/output.txt"
  printf '</pre></body></html>'
} > "$here/sample.html"
"$chrome" --headless --disable-gpu --hide-scrollbars --window-size=980,640 --screenshot="$here/sample.png" "file://$here/sample.html" > /dev/null 2>&1
rm -f "$here/sample.html"
