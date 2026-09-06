#!/bin/bash
# Runs everything that can be verified without Xcode.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Ruleset validation"
node Tools/check-ruleset.js

echo
echo "==> JavaScript engines"
node --test Extension/tests/rules-engine.test.js Extension/tests/schedule-engine.test.js

echo
echo "==> Swift ruleset and schedule engines"
swift test --package-path Packages/QuietCore 2>&1 | tail -3

echo
echo "==> Swift licensing (IndieKit)"
swift test --package-path Packages/IndieKit 2>&1 | tail -3
