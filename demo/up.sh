#!/usr/bin/env bash
# Compatibility wrapper → start.sh
exec "$(cd "$(dirname "$0")" && pwd)/start.sh" "$@"
