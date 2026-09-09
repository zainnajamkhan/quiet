#!/bin/bash
#
#  sync-resources.sh
#  Quiet
#
#  Copies the canonical extension resources into the places Xcode actually builds from.
#
#  Extension/Resources is the copy the Node tests and the ruleset validator run against.
#  Quiet/Shared (Extension)/Resources is the copy that ships inside the extension, and
#  Quiet/macOS (App)/Resources holds the ruleset the app's own rule editor reads. They are
#  separate files on disk, so editing one and shipping another is an easy and completely
#  silent mistake: it already happened once, and the result was a feature that worked in
#  every test and did nothing in the built product.
#
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="Extension/Resources"
EXTENSION="Quiet/Shared (Extension)/Resources"
APP="Quiet/macOS (App)/Resources"

for file in background.js content.js rules-engine.js schedule-engine.js manifest.json ruleset.json; do
  cp "$SOURCE/$file" "$EXTENSION/$file"
  echo "  -> $EXTENSION/$file"
done

# The icon set is a directory, and it was missed the first time round: the extension
# shipped Xcode's template icons for months because they only ever existed in the copy.
rsync -a --delete "$SOURCE/images/" "$EXTENSION/images/"
echo "  -> $EXTENSION/images/"

cp "$SOURCE/ruleset.json" "$APP/ruleset.json"
echo "  -> $APP/ruleset.json"

echo "Resources synced from $SOURCE"
