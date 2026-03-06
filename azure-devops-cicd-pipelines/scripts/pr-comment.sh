#!/usr/bin/env bash
# =============================================================================
# Post Terraform Plan Output as a GitHub PR Comment
# =============================================================================
# Standalone script for posting terraform plan results to a pull request.
# Useful when you can't use actions/github-script (e.g., self-hosted runners
# without Node.js, or Azure DevOps pipelines posting to GitHub PRs).
#
# Usage:
#   ./pr-comment.sh <plan_file> <pr_number> <environment>
#
# Required environment variables:
#   GITHUB_TOKEN  — PAT or GITHUB_TOKEN with pull-requests:write scope
#   GITHUB_REPO   — owner/repo format (e.g., "contoso/infra")
# =============================================================================

set -euo pipefail

# --- Argument validation ---
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <plan_file> <pr_number> <environment>"
  echo "  plan_file:   path to terraform plan output text file"
  echo "  pr_number:   GitHub pull request number"
  echo "  environment: deployment environment name (dev, staging, prod)"
  exit 1
fi

PLAN_FILE="$1"
PR_NUMBER="$2"
ENVIRONMENT="$3"

# Validate required environment variables exist
: "${GITHUB_TOKEN:?'GITHUB_TOKEN environment variable is required'}"
: "${GITHUB_REPO:?'GITHUB_REPO environment variable is required (owner/repo)'}"

GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"

# --- Read and truncate plan output ---
# GitHub comments have a 65536 character limit; truncate gracefully
MAX_CHARS=60000
PLAN_OUTPUT=$(cat "$PLAN_FILE")

if [[ ${#PLAN_OUTPUT} -gt $MAX_CHARS ]]; then
  PLAN_OUTPUT="${PLAN_OUTPUT:0:$MAX_CHARS}

... (truncated — full plan available in pipeline artifacts)"
fi

# --- Build the comment body ---
# Using heredoc with jq to properly escape the plan output as JSON
COMMENT_BODY=$(jq -n \
  --arg env "$ENVIRONMENT" \
  --arg plan "$PLAN_OUTPUT" \
  '{body: "### Terraform Plan 📋\n**Environment:** `\($env)`\n\n<details><summary>Show Plan Output</summary>\n\n```hcl\n\($plan)\n```\n\n</details>"}')

# --- Find existing bot comment to update (avoids PR clutter) ---
EXISTING_COMMENT_ID=$(curl -s \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "${GITHUB_API}/issues/${PR_NUMBER}/comments" \
  | jq -r '.[] | select(.body | contains("Terraform Plan 📋")) | .id' \
  | head -1)

# --- Post or update comment ---
if [[ -n "$EXISTING_COMMENT_ID" && "$EXISTING_COMMENT_ID" != "null" ]]; then
  # Update existing comment to keep PR timeline clean
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "${GITHUB_API}/issues/comments/${EXISTING_COMMENT_ID}" \
    -d "$COMMENT_BODY")

  if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 300 ]]; then
    echo "✅ Updated existing PR comment (ID: ${EXISTING_COMMENT_ID})"
  else
    echo "❌ Failed to update comment (HTTP ${HTTP_STATUS})"
    exit 1
  fi
else
  # Create new comment
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "${GITHUB_API}/issues/${PR_NUMBER}/comments" \
    -d "$COMMENT_BODY")

  if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 300 ]]; then
    echo "✅ Posted new PR comment"
  else
    echo "❌ Failed to create comment (HTTP ${HTTP_STATUS})"
    exit 1
  fi
fi
