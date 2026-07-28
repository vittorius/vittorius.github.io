#!/usr/bin/env bash
# Wait for and verify the GitHub Actions run triggered by a deploy push.
#
# Usage: watch-deploy.sh <DEPLOY_SHA> [BASELINE_RUN_ID]
#
# DEPLOY_SHA        SHA that was force-pushed to gh-pages.
# BASELINE_RUN_ID   Highest deploy.yml run id known *before* the push (default 0).
#                    Needed because pushing the same SHA twice (no new commits)
#                    would otherwise match the previous run and report its
#                    stale conclusion instead of waiting for a new one.
set -uo pipefail

DEPLOY_SHA="$1"
BASELINE="${2:-0}"

# Wait up to ~60s for GitHub to create the run for our push.
RUN_ID=""
for _ in $(seq 1 20); do
  RUN_ID=$(gh run list --workflow=deploy.yml -c "$DEPLOY_SHA" --limit 5 \
    --json databaseId \
    --jq "[.[] | select(.databaseId > $BASELINE)] | max_by(.databaseId).databaseId // empty")
  [ -n "$RUN_ID" ] && break
  sleep 3
done

if [ -z "$RUN_ID" ]; then
  echo "FAILED: no workflow run appeared for $DEPLOY_SHA within 60s" >&2
  exit 2
fi

gh run watch "$RUN_ID" --exit-status --compact -i 5
STATUS=$?
URL=$(gh run view "$RUN_ID" --json url --jq .url)

if [ "$STATUS" -eq 0 ]; then
  echo "DEPLOY OK — $URL — https://vittorius.github.io"
else
  echo "DEPLOY FAILED — $URL" >&2
  gh run view "$RUN_ID" --log-failed 2>&1 | tail -50 >&2
fi
exit "$STATUS"
