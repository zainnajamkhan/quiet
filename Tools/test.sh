#!/bin/bash
# Runs everything that can be verified without Xcode.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Resource copies are in step"
# Xcode builds from Quiet/Shared (Extension)/Resources, not from Extension/Resources, so a
# change made in one and not the other passes every test and ships nothing. That is not
# hypothetical: the remote ruleset sync was written, tested and committed while the built
# extension still had none of it.
DRIFTED=0
for file in background.js content.js rules-engine.js schedule-engine.js manifest.json ruleset.json; do
  if ! diff -q "Extension/Resources/$file" "Quiet/Shared (Extension)/Resources/$file" >/dev/null 2>&1; then
    echo "  DRIFTED: $file differs from the copy that ships"
    DRIFTED=1
  fi
done
if ! diff -q "Extension/Resources/ruleset.json" "Quiet/macOS (App)/Resources/ruleset.json" >/dev/null 2>&1; then
  echo "  DRIFTED: ruleset.json differs from the copy the app reads"
  DRIFTED=1
fi
if [ "$DRIFTED" = "1" ]; then
  echo "  Run Tools/sync-resources.sh"
  exit 1
fi
echo "  OK   every shipped copy matches Extension/Resources"

echo
echo "==> Ruleset validation"
node Tools/check-ruleset.js

echo
echo "==> Regenerating selector check snippet"
node Tools/make-selector-check.js

echo
echo "==> JavaScript engines"
node --test Extension/tests/rules-engine.test.js Extension/tests/schedule-engine.test.js Extension/tests/selector-check-snippet.test.js

echo
echo "==> Swift ruleset and schedule engines"
swift test --package-path Packages/QuietCore 2>&1 | tail -3

echo
echo "==> Swift licensing (IndieKit)"
swift test --package-path Packages/IndieKit 2>&1 | tail -3
