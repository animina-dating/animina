#!/bin/bash

MIX_FILE="mix.exs"
VERSION_REGEX='version: "[0-9]+\.[0-9]+\.[0-9]+"'

if [[ ! -f "$MIX_FILE" ]]; then
  echo "mix.exs file not found!"
  exit 1
fi

if [[ $(git diff --stat) != '' ]]; then
  echo "Working directory is dirty. Please commit any pending changes."
  exit 1
fi

current_version=$(awk -F\" '/version: / {print $2}' "$MIX_FILE")
IFS='.' read -r -a version_parts <<< "$current_version"

major=${version_parts[0]}
minor=${version_parts[1]}
patch=${version_parts[2]}
new_patch=$((patch + 1))
new_version="$major.$minor.$new_patch"

sed -i -E "s/$VERSION_REGEX/version: \"$new_version\"/" "$MIX_FILE"

git config user.email "github-actions[bot]@users.noreply.github.com"
git config user.name "GitHub Action"

branch_name="version-bump-$new_version-$(date +%s)"
git checkout -b "$branch_name"
git add "$MIX_FILE"
git commit -m "Bump version to $new_version"
git push origin "$branch_name"

# Set the branch name for GitHub Actions output
echo "branch=$branch_name" >> $GITHUB_ENV
