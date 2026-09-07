#!/bin/bash
#
#  publish-ruleset.sh
#  Quiet
#
#  Stages the current ruleset for hosting, after checking it is safe to publish.
#
#  A published ruleset is the one part of Quiet a third party can change after install, and
#  every copy of the app will fetch it. A broken publish is therefore not a small mistake,
#  so this refuses to stage anything that would be rejected at install time, rather than
#  finding out from users.
#
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="Extension/Resources/ruleset.json"
PUBLISHED="Rules/published/ruleset.json"

echo "==> Validating $SOURCE"
node Tools/check-ruleset.js "$SOURCE"

SOURCE_VERSION=$(python3 -c "import json;print(json.load(open('$SOURCE'))['rulesetVersion'])")

if [ -f "$PUBLISHED" ]; then
  PUBLISHED_VERSION=$(python3 -c "import json;print(json.load(open('$PUBLISHED'))['rulesetVersion'])")
  if [ "$SOURCE_VERSION" -le "$PUBLISHED_VERSION" ]; then
    echo
    echo "REFUSED: rulesetVersion is $SOURCE_VERSION, but $PUBLISHED_VERSION is already published."
    echo "Apps only adopt a ruleset with a HIGHER version, so this would reach nobody."
    echo "Bump rulesetVersion in $SOURCE first."
    exit 1
  fi
fi

cp "$SOURCE" "$PUBLISHED"
echo "==> Staged version $SOURCE_VERSION at $PUBLISHED"
echo
echo "Commit and push it. The app fetches whatever URL is set in"
echo "HTTPRulesetSource.url, so that URL must serve this file."
