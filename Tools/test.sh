#!/bin/bash
# Runs everything that can be verified without Xcode.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Ruleset validation"
node Tools/check-ruleset.js

echo
echo "==> JavaScript engine"
node --test Extension/tests/rules-engine.test.js

echo
echo "==> Swift engine"
swift test --package-path Packages/QuietCore 2>&1 | tail -3
