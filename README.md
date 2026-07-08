# logisk-platform-agent-kit

Skills that make a customer's AI agent (Claude Code, etc.) fluent in the Logiskbrist platform — regardless of which directory the agent is in.

Once installed, the customer can say things like:

- "Start a new app called blog" → the agent runs `/new-app`, creates the repo from your template, wires up the topic, pushes, and reports the URL.
- "What apps do we have?" → the agent runs `/list-apps` and shows every repo tagged `logisk-platform` in the customer's org.

Without this kit, an agent needs to be told the customer's org, domain, and template repo every time — or has to be pointed at a specific project's `CLAUDE.md`. This kit puts that context in `~/.claude/skills/` so it's implicit.

## Install

```bash
git clone https://github.com/godtbrod/logisk-platform-agent-kit ~/logisk-agent-kit
cd ~/logisk-agent-kit
./install.sh
```

The installer prompts for the customer's GitHub org, domain, and template repo name. Non-interactive:

```bash
LOGISK_CUSTOMER_ORG=godtbrod \
LOGISK_CUSTOMER_DOMAIN=aks-prod.logiskbrist.no \
LOGISK_TEMPLATE_REPO=logisk-app-template \
./install.sh
```

Re-run any time to reconfigure. Skills that already exist under `~/.claude/skills/` but weren't installed by this kit are left alone.

## What it installs

- `~/.claude/skills/new-app/SKILL.md`
- `~/.claude/skills/list-apps/SKILL.md`

Both files have your customer-specific values (org, domain, template) baked in at install time.

## Prereqs on the customer's machine

- Claude Code (or another agent that reads `~/.claude/skills/`).
- `gh` CLI, authenticated as a member of the customer's org with `repo` + `admin:org` scope.

## Not installed by this kit

Per-app skills (`/set-secret`, `/check-deploy`, `/rollback`, etc.) live inside each app's repo — they're part of the template. They're specific to one app at a time; the skills here are ORG-level and work before any specific app repo exists.

## Uninstall

```bash
rm -rf ~/.claude/skills/new-app ~/.claude/skills/list-apps
```

Any skill directory without a `.logisk-installed` marker was not created by this kit and won't be touched.
