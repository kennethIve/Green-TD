#!/usr/bin/env bash
# Deploy build/web to the gh-pages branch for GitHub Pages.
# Requires GH_TOKEN with repo write access.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_DIR="${ROOT}/build/web"
REPO_SLUG="${GITHUB_REPOSITORY:-kennethIve/Green-TD}"
BRANCH="gh-pages"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

if [[ ! -d "$WEB_DIR" ]]; then
  echo "ERROR: $WEB_DIR not found. Export the web build first." >&2
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "ERROR: GH_TOKEN is not set." >&2
  exit 1
fi

CLONE_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO_SLUG}.git"

echo "Cloning ${REPO_SLUG} (${BRANCH})..."
if git ls-remote --heads "$CLONE_URL" "$BRANCH" | grep -q "$BRANCH"; then
  git clone --depth 1 --branch "$BRANCH" "$CLONE_URL" "$TMP_DIR/site"
else
  git clone --depth 1 "$CLONE_URL" "$TMP_DIR/site"
  cd "$TMP_DIR/site"
  git checkout --orphan "$BRANCH"
  git rm -rf . >/dev/null 2>&1 || true
fi

cd "$TMP_DIR/site"
# Remove previous published files (keep .git)
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

echo "Copying web build from $WEB_DIR..."
cp -a "$WEB_DIR"/. .

# Ensure GitHub Pages does not run Jekyll
touch .nojekyll

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git add -A
if git diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi

git commit -m "Deploy web build to GitHub Pages"
git push origin "HEAD:${BRANCH}"
echo "Deployed to https://kennethive.github.io/Green-TD/"
