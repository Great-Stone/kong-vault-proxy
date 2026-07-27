#!/usr/bin/env bash
# Compatibility wrapper → stop.sh
exec "$(cd "$(dirname "$0")" && pwd)/stop.sh" "$@"
