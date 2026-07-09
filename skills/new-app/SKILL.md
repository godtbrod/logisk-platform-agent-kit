---
name: new-app
description: Create a new app on the Logiskbrist platform from the customer's template repo. Use whenever the user asks to start a new app, spin up a new service, add a new project, bootstrap a new deployable, or "create a new repo for X" in the context of shipping something.
---

# Create a new app on the Logiskbrist platform

## Platform context

You are helping a developer whose apps are deployed on Logiskbrist's managed AKS platform.

- **GitHub org**: `{{CUSTOMER_ORG}}`
- **Domain**: `{{CUSTOMER_DOMAIN}}`
- **App template**: `{{CUSTOMER_ORG}}/{{TEMPLATE_REPO}}`

New apps deploy to `<name>.{{CUSTOMER_DOMAIN}}` (prod) and `<branch-slug>-<name>.{{CUSTOMER_DOMAIN}}` (a preview per PR/branch). The platform auto-discovers any repo in `{{CUSTOMER_ORG}}` tagged with topic `logisk-platform` — that's the ONLY thing that makes an app real to the platform.

## Architecture rule — read this first

**Every app is EITHER a backend service OR a frontend. Never both in one Deployment.** No `useStaticAssets` in Nest, no `/api/*` routes in the frontend. If the customer's request implies both a UI and API logic, you create **two apps** (usually named `<name>-api` and `<name>-web`) and wire them together. This is a hard platform rule — the customer's whole architecture depends on it.

The shipped template is a NestJS backend. For frontend apps, you convert it after creation using §Converting this template to a frontend from the repo's `CLAUDE.md`.

## Steps — do these in order

### 0. Understand what the user is asking for

Read the user's request. Classify it as one of:

- **Backend only** — API, service, worker, cron, anything without a UI. Examples: "an email sending service", "a scheduler", "an API for our mobile app".
- **Frontend only** — a website or SPA that talks to an existing backend. Examples: "an admin dashboard for the users API", "a landing page".
- **Full-stack (both)** — a product that has both a UI and its own backend. Examples: "a blog with an admin login", "a customer portal", "a Q&A site".

Rule of thumb: if the user mentions a database, authentication logic, business rules, or third-party API integration, it needs a backend. If they mention a UI, pages, forms, dashboards, or "a website", it needs a frontend. Both → full-stack.

If it's ambiguous, ask a short clarifying question. Don't guess wrong — the wrong classification wastes a whole repo.

Pick your plan based on the classification:

| Classification | Plan |
|---|---|
| Backend only | One repo, name as user requested, no conversion. |
| Frontend only | One repo, name as user requested, run the conversion recipe from `CLAUDE.md` after creation. |
| Full-stack | Two repos: `<name>-api` (backend, no conversion) and `<name>-web` (frontend, converted). Wire `VITE_API_URL` on `-web` to point at `-api`'s public URL. |

### 1. Pick a name

If the user didn't provide one, ask. The name must be:
- lowercase kebab-case, matching `^[a-z][a-z0-9-]+$`
- short (it appears in URLs and Docker tags)
- not already a repo in `{{CUSTOMER_ORG}}` — check with `gh repo view {{CUSTOMER_ORG}}/<name> 2>/dev/null && echo EXISTS || echo OK`

For **full-stack**, suffix the base name: `blog` → create `blog-api` and `blog-web`. Check both names are free before creating anything.

### 2. Create the repo(s) from the template

For each repo you're creating (one for backend-only or frontend-only, two for full-stack), run:

```bash
gh repo create {{CUSTOMER_ORG}}/$APP \
  --template {{CUSTOMER_ORG}}/{{TEMPLATE_REPO}} \
  --private \
  --clone
cd $APP
```

### 3. Substitute placeholders in the manifests

```bash
find manifests .github -type f -name '*.yaml' -exec sed -i.bak \
  -e "s|PLACEHOLDER_APP|$APP|g" \
  -e "s|PLACEHOLDER_CUSTOMERORG|{{CUSTOMER_ORG}}|g" \
  -e "s|PLACEHOLDER_CUSTOMER_DOMAIN|{{CUSTOMER_DOMAIN}}|g" {} \;
find manifests .github -name '*.bak' -delete
```

**Do NOT touch** `PLACEHOLDER_TAG` or `PLACEHOLDER_HOST` — those are patched at runtime by the platform's CI and ArgoCD.

### 4. Update `package.json` name

```bash
sed -i.bak "s|\"name\": \"logisk-app-template\"|\"name\": \"$APP\"|" package.json && rm package.json.bak
```

### 5. If this repo is a frontend, convert it now

Skip this step for backend repos.

For a frontend repo:

1. Open the repo's `CLAUDE.md` and locate the section **"Converting this template to a frontend"**.
2. Execute every numbered step in that section in order. It covers file deletions, the new `Dockerfile`, `nginx.conf`, `package.json`, Vite scaffolding, manifest port changes, and `.dockerignore` update.
3. When it says "Set the backend URL", use the paired backend repo's URL:
   - Full-stack: `https://<basename>-api.{{CUSTOMER_DOMAIN}}` where `<basename>` is the user's original name (e.g. `blog` for `blog-web`).
   - Frontend-only: ask the user which existing backend to talk to; use its public URL.
   ```bash
   gh workflow run set-secret.yaml -f name=VITE_API_URL -f value='https://<backend>.{{CUSTOMER_DOMAIN}}'
   ```

Do the full recipe, not a partial. The app must be end-to-end a frontend or end-to-end a backend before the first push.

### 6. Tag the repo — this is what makes the platform pick it up

```bash
gh repo edit --add-topic logisk-platform
```

Without this topic, ArgoCD's SCM Provider will not discover the repo. The app will never deploy.

### 7. Commit and push

```bash
git add -A
git commit -m "initial customization for $APP"
git push
```

### 8. Report the result to the user

State plainly:

- The prod URL(s):
  - Backend/single: `https://$APP.{{CUSTOMER_DOMAIN}}/` — live within ~2 minutes.
  - Full-stack: two URLs, `https://<name>-api.{{CUSTOMER_DOMAIN}}/` and `https://<name>-web.{{CUSTOMER_DOMAIN}}/`. Mention that the `-web` app has already been wired to call `-api` via `VITE_API_URL`.
- Every non-main branch push auto-opens a draft PR and creates a preview at `https://<branch-slug>-<name>.{{CUSTOMER_DOMAIN}}/`.
- Secrets go through `/set-secret` from inside each app's repo.
- What the initial app looks like: a NestJS backend serves `hello from <name>` on `/`; a frontend serves a placeholder React page.

Include the repo URL(s): `https://github.com/{{CUSTOMER_ORG}}/<name>`.

For full-stack, remind the user: **"These are two separate apps that ship independently. Editing the frontend won't affect the backend and vice versa. They talk to each other via HTTP."**

## Verifying it worked (optional)

If the user wants confirmation the deploy fired:

```bash
gh run watch --repo {{CUSTOMER_ORG}}/$APP
```

Wait until the `build` workflow succeeds, then curl the prod URL. Expect `hello from $APP` (backend) or an HTML page (frontend).

## Failure modes and remediation

- **"Repository already exists"** — pick a different name or ask the user which suffix they want.
- **"template repository is not accessible"** — the template must have `isTemplate: true`. Verify with `gh repo view {{CUSTOMER_ORG}}/{{TEMPLATE_REPO}} --json isTemplate`. If false, the person who seeded the template forgot to flip it — ask them to run `gh api -X PATCH /repos/{{CUSTOMER_ORG}}/{{TEMPLATE_REPO}} -f is_template=true`.
- **First build fails on GHCR push** — the org's `ghcr.io` PAT is stale. This isn't fixable from the app repo; report it to whoever owns the org.
- **Build succeeds but the URL 404s after 5 minutes** — the topic didn't stick. Re-check with `gh repo view {{CUSTOMER_ORG}}/$APP --json repositoryTopics`. If empty, re-run step 6.
- **`gh` reports permission errors on topic or repo creation** — the user's PAT is missing `admin:org` or `repo` scope. `gh auth refresh -s admin:org,repo` fixes it.
- **Frontend build bakes an empty `VITE_API_URL`** — you forgot to `/set-secret` before the first push. Push a no-op commit after setting it; the rebuild will pick up the value.

## What NOT to do

- Do not skip step 0 (classify the app) — creating a frontend as if it were a backend, or vice versa, wastes a repo.
- Do not try to serve HTML from a NestJS backend or add an API to a frontend. See §Architecture in the repo's `CLAUDE.md`.
- Do not edit `manifests/base/service.yaml`, `manifests/base/deployment.yaml`, or `manifests/base/external-secret.yaml` beyond the placeholder substitution above and the port changes the frontend conversion recipe describes — the AppSet's preview patches depend on their exact shape.
- Do not create the repo blank and copy files in — always use `--template`, otherwise `is_template=true` provenance is lost and template updates won't propagate.
- Do not push directly to `main` for iteration — push a branch. Every branch push spawns a preview URL.
