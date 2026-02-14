#!/bin/bash

set -e

MAIN_BRANCH="main"

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Not a git repository."
  exit 1
}

# Ensure main exists
git show-ref --verify --quiet "refs/heads/$MAIN_BRANCH" || {
  echo "Branch '$MAIN_BRANCH' does not exist."
  exit 1
}

# Switch to main
git checkout "$MAIN_BRANCH" >/dev/null 2>&1

# Collect branches to delete
BRANCHES=$(git branch | sed 's/^\*//' | grep -vE "^\s*$MAIN_BRANCH$" || true)

if [[ -z "$BRANCHES" ]]; then
  echo "No branches to delete. You're already clean."
  exit 0
fi

echo
echo "The following local branches will be deleted:"
echo "-------------------------------------------"
echo "$BRANCHES"
echo

read -p 'Type "yes" to permanently delete these branches: ' CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted. No branches were deleted."
  exit 0
fi

echo
echo "Deleting branches..."
echo

while read -r branch; do
  echo "Deleting: $branch"
  git branch -D "$branch"
done <<< "$BRANCHES"

echo
echo "Done."