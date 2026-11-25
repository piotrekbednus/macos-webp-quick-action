#!/bin/bash
set -uo pipefail

failed=0
for name in "Convert to WebP.workflow" "Convert to AVIF.workflow"; do
  path="$HOME/Library/Services/$name"
  if [ ! -e "$path" ]; then
    echo "Not installed: $name"
  elif rm -rf "$path" && [ ! -e "$path" ]; then
    echo "Removed $name"
  else
    echo "Could not remove $name" >&2
    failed=1
  fi
done

/System/Library/CoreServices/pbs -flush
exit $failed
