#!/usr/bin/env bash
# Installs the Logisk Platform agent skills into ~/.claude/skills/ so any Claude Code
# session — regardless of which directory the user is in — can spin up a new app or
# list existing ones.
#
# Skills installed:
#   /new-app     — bootstrap a new app repo from the customer's template
#   /list-apps   — list every repo tagged `logisk-platform` in the customer's org
#
# Idempotent. Re-run to reconfigure (e.g. change the org).
#
# Environment overrides (skip the prompts):
#   LOGISK_CUSTOMER_ORG=godtbrod \
#   LOGISK_CUSTOMER_DOMAIN=aks-prod.logiskbrist.no \
#   LOGISK_TEMPLATE_REPO=logisk-app-template \
#   ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude/skills"

# --- output helpers ---------------------------------------------------------
_bold() { printf '\033[1m%s\033[0m' "$*"; }
banner() { printf '\n\033[1;36m==\033[0m \033[1m%s\033[0m\n' "$*"; }
info()   { printf '   %s\n' "$*"; }
ok()     { printf '   \033[1;32m✓\033[0m %s\n' "$*"; }
warn()   { printf '   \033[1;33m!\033[0m %s\n' "$*"; }
die()    { printf '\n\033[1;31mERROR:\033[0m %s\n\n' "$*" >&2; exit 1; }

banner "Logisk Platform agent kit — install"

# --- collect config ---------------------------------------------------------
CUSTOMER_ORG="${LOGISK_CUSTOMER_ORG:-}"
CUSTOMER_DOMAIN="${LOGISK_CUSTOMER_DOMAIN:-}"
TEMPLATE_REPO="${LOGISK_TEMPLATE_REPO:-logisk-app-template}"

if [ -z "$CUSTOMER_ORG" ]; then
  read -rp "GitHub org that owns your apps (e.g. godtbrod): " CUSTOMER_ORG
fi
if [ -z "$CUSTOMER_DOMAIN" ]; then
  read -rp "Customer domain (e.g. aks-prod.logiskbrist.no): " CUSTOMER_DOMAIN
fi

[ -n "$CUSTOMER_ORG" ]    || die "GitHub org is required."
[ -n "$CUSTOMER_DOMAIN" ] || die "Customer domain is required."

# --- prereq checks (informational, don't block install) ---------------------
banner "Prereqs"
if command -v gh >/dev/null 2>&1; then
  ok "gh CLI ($(gh --version | head -n1))"
  if ! gh auth status >/dev/null 2>&1; then
    warn "gh is installed but not authenticated — run \`gh auth login\` before using the skills."
  fi
else
  warn "gh CLI not found. Install from https://cli.github.com/ — the skills shell out to it."
fi

# --- install skills ---------------------------------------------------------
banner "Installing skills to $DEST"
mkdir -p "$DEST"

INSTALLED=0
SKIPPED=0
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  name="$(basename "$skill_dir")"
  target="$DEST/$name"
  marker="$target/.logisk-installed"

  # Don't clobber a skill by the same name that someone else authored.
  if [ -d "$target" ] && [ ! -f "$marker" ]; then
    warn "/$name exists at $target and wasn't installed by this kit — skipping. Delete it and re-run to install."
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  mkdir -p "$target"
  sed \
    -e "s|{{CUSTOMER_ORG}}|$CUSTOMER_ORG|g" \
    -e "s|{{CUSTOMER_DOMAIN}}|$CUSTOMER_DOMAIN|g" \
    -e "s|{{TEMPLATE_REPO}}|$TEMPLATE_REPO|g" \
    "$skill_dir/SKILL.md" > "$target/SKILL.md"

  cat > "$marker" <<EOF
Installed by logisk-platform-agent-kit on $(date -u +%Y-%m-%dT%H:%M:%SZ).
CUSTOMER_ORG=$CUSTOMER_ORG
CUSTOMER_DOMAIN=$CUSTOMER_DOMAIN
TEMPLATE_REPO=$TEMPLATE_REPO
Re-run install.sh to update.
EOF

  ok "/$name"
  INSTALLED=$((INSTALLED + 1))
done

# --- summary ----------------------------------------------------------------
banner "Done"
info "Installed $INSTALLED skill(s)$([ "$SKIPPED" -gt 0 ] && printf ', skipped %s.' "$SKIPPED" || printf '.')"
info ""
info "Config baked in:"
info "  Org      = $CUSTOMER_ORG"
info "  Domain   = $CUSTOMER_DOMAIN"
info "  Template = $CUSTOMER_ORG/$TEMPLATE_REPO"
info ""
info "Try it in Claude Code:"
info "  \"Start a new app called blog\""
info "  \"What apps do we have?\""
info ""
info "Re-run this script anytime to reconfigure."
