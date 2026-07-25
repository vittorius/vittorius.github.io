---
name: deploy
description: Deploy the blog using Github Pages
disable-model-invocation: false
---

- Ensure the Git worktree is clean
- Switch to the `gh-pages` Git branch
- Reset the local `gh-pages` branch to the content of the local `main` branch
- Force push from the local `gh-pages` branch to the remote `gh-pages` branch
