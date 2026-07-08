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

New apps deploy to `<app>.{{CUSTOMER_DOMAIN}}` (prod) and `<branch-slug>-<app>.{{CUSTOMER_DOMAIN}}` (a preview per PR/branch). The platform auto-discovers any repo in `{{CUSTOMER_ORG}}` tagged with topic `logisk-platform` — that's the ONLY thing that makes an app real to the platform.

## Steps — do these in order

### 1. Pick a name

If the user didn't provide one, ask. The name must be:
- lowercase kebab-case, matching `^[a-z][a-z0-9-]+$`
- short (it appears in URLs and Docker tags)
- not already a repo in `{{CUSTOMER_ORG}}` — check with `gh repo view {{CUSTOMER_ORG}}/<name> 2>/dev/null && echo EXISTS || echo OK`

Set `APP=<name>` and use it throughout.

### 2. Create the repo from the template

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

### 5. Tag the repo — this is what makes the platform pick it up

```bash
gh repo edit --add-topic logisk-platform
```

Without this topic, ArgoCD's SCM Provider will not discover the repo. The app will never deploy.

### 6. Commit and push

```bash
git add -A
git commit -m "initial customization for $APP"
git push
```

### 7. Report the result to the user

State plainly:

- Prod URL: `https://$APP.{{CUSTOMER_DOMAIN}}/` — live within ~2 minutes (first HTTP01 cert issuance adds another 30-90s the first time someone hits it).
- Every non-main branch push will auto-open a draft PR and create a preview at `https://<branch-slug>-$APP.{{CUSTOMER_DOMAIN}}/`.
- Secrets go through `/set-secret` from **inside the app repo** (the skill is bundled with the template).
- The initial app is a minimal NestJS on port 4000 with `/`, `/health`, and `/env-demo`. Edit `src/*.ts` from here.

Include the repo URL: `https://github.com/{{CUSTOMER_ORG}}/$APP`.

## Verifying it worked (optional)

If the user wants confirmation the deploy fired:

```bash
gh run watch --repo {{CUSTOMER_ORG}}/$APP
```

Wait until the `build` workflow succeeds, then curl the prod URL. Expect `hello from $APP`.

## Failure modes and remediation

- **"Repository already exists"** — pick a different name or ask the user which suffix they want.
- **"template repository is not accessible"** — the template must have `isTemplate: true`. Verify with `gh repo view {{CUSTOMER_ORG}}/{{TEMPLATE_REPO}} --json isTemplate`. If false, the person who seeded the template forgot to flip it — ask them to run `gh api -X PATCH /repos/{{CUSTOMER_ORG}}/{{TEMPLATE_REPO}} -f is_template=true`.
- **First build fails on GHCR push** — the org's `ghcr.io` PAT is stale. This isn't fixable from the app repo; report it to whoever owns the org.
- **Build succeeds but the URL 404s after 5 minutes** — the topic didn't stick. Re-check with `gh repo view {{CUSTOMER_ORG}}/$APP --json repositoryTopics`. If empty, re-run step 5.
- **`gh` reports permission errors on topic or repo creation** — the user's PAT is missing `admin:org` or `repo` scope. `gh auth refresh -s admin:org,repo` fixes it.

## What NOT to do

- Do not edit `manifests/base/service.yaml`, `manifests/base/deployment.yaml`, or `manifests/base/external-secret.yaml` beyond the placeholder substitution above — the AppSet's preview patches depend on their exact shape.
- Do not create the repo blank and copy files in — always use `--template`, otherwise `is_template=true` provenance is lost and template updates won't propagate.
- Do not push directly to `main` for iteration — push a branch. Every branch push spawns a preview URL.
