#!/bin/sh
# Runs SwiftLint with the repo's .swiftlint.yml. Install once with: brew install swiftlint
set -eu
cd "$(dirname "$0")/.."
if ! command -v swiftlint >/dev/null 2>&1; then
  echo "SwiftLint isn't installed. Install it with: brew install swiftlint" >&2
  exit 1
fi
swiftlint lint "$@"
