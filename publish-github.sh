#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
repo="${1:-tishe-interior}"
if [[ ! "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$ ]]; then
  echo 'Use a repository name containing letters, numbers, dots, dashes or underscores.' >&2
  exit 1
fi
for command_name in git gh; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing $command_name. Install Git and GitHub CLI, then run this script again." >&2
    exit 1
  fi
done
[[ -f dist/index.html && -f .github/workflows/pages.yml ]] || { echo 'Website files are missing.' >&2; exit 1; }
echo 'Publishing this portfolio concept as a PUBLIC GitHub repository and GitHub Pages site.'
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  gh auth login --hostname github.com --git-protocol https --web --scopes workflow
fi
if [[ -z ${GH_TOKEN+x} && -z ${GITHUB_TOKEN+x} ]]; then
  auth_status="$(gh auth status --hostname github.com 2>&1)"
  if [[ "$auth_status" != *workflow* ]]; then
    gh auth refresh --hostname github.com --scopes workflow
  fi
fi
gh auth setup-git --hostname github.com
login="$(gh api user --jq .login)"
user_id="$(gh api user --jq .id)"
full_repo="$login/$repo"
expected_remote="https://github.com/$full_repo.git"
if [[ ! -d .git ]]; then
  if gh repo view "$full_repo" --json name >/dev/null 2>&1; then
    echo "Repository $full_repo already exists. Run: bash publish-github.sh a-different-name" >&2
    exit 1
  fi
  git init -b main
fi
branch="$(git branch --show-current)"
[[ "$branch" == main ]] || { echo 'This script expects the main branch.' >&2; exit 1; }
if git remote get-url origin >/dev/null 2>&1; then
  origin="$(git remote get-url origin)"
  [[ "$origin" == "$expected_remote" || "$origin" == "git@github.com:$full_repo.git" ]] || { echo 'Existing Git remote points to another repository.' >&2; exit 1; }
fi
git add dist .github .gitignore README.md vercel.json download-assets.py publish-github.sh publish-github.ps1
if ! git diff --cached --quiet; then
  git -c "user.name=$login" -c "user.email=$user_id+$login@users.noreply.github.com" commit -m 'Add interior studio portfolio landing page'
fi
if git remote get-url origin >/dev/null 2>&1; then
  git push --set-upstream origin main
else
  gh repo create "$full_repo" --public --description 'Interior design studio landing page - portfolio concept' --source . --remote origin --push
fi
if gh api "repos/$full_repo/pages" >/dev/null 2>&1; then
  gh api --method PATCH "repos/$full_repo/pages" -f build_type=workflow >/dev/null
else
  gh api --method POST "repos/$full_repo/pages" -f build_type=workflow >/dev/null
fi
previous_run_id="$(gh run list --repo "$full_repo" --workflow pages.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
gh workflow run pages.yml --repo "$full_repo" --ref main
run_id=''
for attempt in {1..15}; do
  run_id="$(gh run list --repo "$full_repo" --workflow pages.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
  [[ -n "$run_id" && "$run_id" != "$previous_run_id" ]] && break
  echo 'Waiting for the deployment workflow...'
  sleep 2
done
if [[ -z "$run_id" || "$run_id" == "$previous_run_id" ]]; then
  echo "Workflow requested. Check: https://github.com/$full_repo/actions" >&2
  exit 1
fi
gh run watch "$run_id" --repo "$full_repo" --exit-status
demo_url="$(gh api "repos/$full_repo/pages" --jq .html_url)"
printf '\nRepository: https://github.com/%s\nDemo: %s\n' "$full_repo" "$demo_url"
