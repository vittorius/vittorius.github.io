.PHONY: deploy preflight push verify report
.DEFAULT_GOAL := deploy

WATCH_SCRIPT := ./watch-deploy.sh
SHELL := /bin/bash

# Preflight check: ensure git worktree is clean
preflight:
	@if ! git status --porcelain | grep -q .; then \
		echo "✓ Worktree clean"; \
	else \
		echo "✗ Worktree not clean:"; \
		git status --porcelain; \
		exit 1; \
	fi

# Capture baseline before touching branches
capture-baseline: preflight
	@DEPLOY_SHA=$$(git rev-parse main); \
	BASELINE=$$(gh run list --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId // 0'); \
	echo "$$DEPLOY_SHA" > .make-deploy-sha; \
	echo "$$BASELINE" > .make-deploy-baseline; \
	echo "Captured: SHA=$$DEPLOY_SHA BASELINE=$$BASELINE"

# Push to gh-pages branch
push: capture-baseline
	@CURRENT_BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	git switch gh-pages; \
	git reset --hard main; \
	git push --force origin gh-pages; \
	git switch -; \
	echo "✓ Pushed to gh-pages and switched back to $$CURRENT_BRANCH"

# Verify deployment via watch script
verify: push
	@DEPLOY_SHA=$$(cat .make-deploy-sha); \
	BASELINE=$$(cat .make-deploy-baseline); \
	$(WATCH_SCRIPT) "$$DEPLOY_SHA" "$$BASELINE"

# Deploy target: runs the full pipeline
deploy: verify
	@rm -f .make-deploy-sha .make-deploy-baseline
	@echo "✓ Deployment complete"

# Clean up temp files
clean:
	@rm -f .make-deploy-sha .make-deploy-baseline
	@echo "✓ Cleaned up temporary files"
