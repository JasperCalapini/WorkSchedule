#!/bin/sh
# Bumps the app version in GigLog.xcodeproj (both the app and the Lock Screen widget).
#
#   scripts/bump-version.sh build          1.0.0 (1) -> 1.0.0 (2)   every TestFlight/Xcode install you keep
#   scripts/bump-version.sh patch          1.0.0 -> 1.0.1           bug fixes
#   scripts/bump-version.sh minor          1.0.1 -> 1.1.0           new features
#   scripts/bump-version.sh major          1.1.0 -> 2.0.0           big changes
#
# patch/minor/major also bump the build number. Then add a section to CHANGELOG.md and commit.
set -eu

project="$(dirname "$0")/../GigLog.xcodeproj/project.pbxproj"
part="${1:-}"

version=$(grep -m1 'MARKETING_VERSION = ' "$project" | sed -E 's/.*= ([0-9.]+);/\1/')
build=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$project" | sed -E 's/.*= ([0-9]+);/\1/')
major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)

case "$part" in
  build) ;;
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
  *) echo "usage: $0 build|patch|minor|major" >&2; exit 1 ;;
esac
new_version="$major.$minor.$patch"
new_build=$((build + 1))

# Write to a temp file so this works with both macOS and GNU sed.
tmp="$project.tmp"
sed -e "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $new_version;/" \
    -e "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $new_build;/" \
    "$project" > "$tmp"
mv "$tmp" "$project"

echo "Version $version ($build) -> $new_version ($new_build)"
