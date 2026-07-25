---
name: deploy
description: Deploy the blog using Github Pages
disable-model-invocation: false
---

1. **Preflight.** Ensure the Git worktree is clean (`git status --porcelain` is
   empty). Stop and report if not.

2. **Capture a baseline**, before touching any branches:

   ```bash
   DEPLOY_SHA=$(git rev-parse main)
   BASELINE=$(gh run list --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId // 0')
   ```

3. **Push.**
   - Switch to the `gh-pages` Git branch.
   - Reset the local `gh-pages` branch to the content of the local `main`
     branch.
   - Force push from the local `gh-pages` branch to the remote `gh-pages`
     branch.
   - Switch back to the previous branch (`git switch -`).

4. **Verify.** Run the deploy workflow to completion and check its result:

   ```bash
   .agents/skills/deploy/watch-deploy.sh "$DEPLOY_SHA" "$BASELINE"
   ```

   Give this a generous timeout (10 minutes) — it blocks until the GitHub
   Actions run for this push finishes, streaming step progress, and exits
   non-zero if the run fails or is cancelled.

5. **Report.** On exit 0, report success with the run URL and
   `https://vittorius.github.io`. On non-zero, report the run's conclusion and
   the failing-step log the script printed to stderr. Never report the deploy
   as successful without a zero exit from step 4.
