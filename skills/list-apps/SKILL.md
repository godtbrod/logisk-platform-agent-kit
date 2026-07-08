---
name: list-apps
description: List all apps deployed on the Logiskbrist platform for this customer. Use when the user asks what apps they have, wants a project overview, "what's deployed", "what did we ship", or is trying to remember an app name.
---

# List apps on the Logiskbrist platform

Query GitHub for every repo in `{{CUSTOMER_ORG}}` tagged with topic `logisk-platform` — that's the ground truth of which repos are wired to the platform:

```bash
gh repo list {{CUSTOMER_ORG}} --topic logisk-platform --limit 100 --json name,url,description,updatedAt \
  --jq '.[] | "\(.name)\t\(.url)\thttps://\(.name).{{CUSTOMER_DOMAIN}}/\tupdated \(.updatedAt | fromdate | strftime("%Y-%m-%d"))"' \
  | column -ts $'\t'
```

Present the output as a table with columns: **name**, **repo**, **prod URL**, **last update**.

## When the list is empty

The user hasn't created any apps yet, or the topic wasn't set on the ones they made. Suggest they run "start a new app" — that fires the `/new-app` skill and does topic-tagging correctly.

## When a repo appears but the URL 404s

Two common causes:
- The repo hasn't been pushed to `main` yet (no image to deploy).
- The topic was added AFTER the first push and the SCM Provider hasn't reconciled — it polls every 60s. Wait a minute, then retry.

## Adjacent things the user might want

- Deploy status of a specific app → suggest running `/check-deploy` from inside that app's repo.
- All PRs across apps (open previews) → `gh search prs --owner {{CUSTOMER_ORG}} --state open --json repository,number,title,url`.
- Which repos are NOT on the platform (missing the topic) → `gh repo list {{CUSTOMER_ORG}} --limit 100 --json name,repositoryTopics --jq '.[] | select(.repositoryTopics | map(.name) | index("logisk-platform") | not) | .name'`.
