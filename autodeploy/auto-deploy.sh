#!/usr/bin/env bash
#
# Option A: poll the watched repos and rebuild the site when any main moves.
# Runs from a systemd user timer on the VPS. See autodeploy/README.md.
#
# Everything lives inside main() so the whole script is parsed into memory
# before it runs. That way a `git reset --hard` on this very repo mid-run can
# never swap the script out from under the running shell.
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-$HOME/deploy/site-deployment}"
STATE_FILE="${STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/smavl-deploy/last-deployed}"
BRANCH="${BRANCH:-main}"

# name|source. "self" uses the local clone's configured remote (works even if
# site-deployment is private); the others are read anonymously over https.
REPOS=(
    "site-deployment|self"
    "zola-site|https://github.com/Smavl/zola-site.git"
    "BackdoorBag|https://github.com/Smavl/BackdoorBag.git"
)

log() { printf '%s  %s\n' "$(date -Is)" "$*"; }

remote_sha() {
    # $1 = https url, or "self" for the deploy repo's own remote
    if [ "$1" = "self" ]; then
        git -C "$DEPLOY_DIR" ls-remote origin "refs/heads/$BRANCH" | awk 'NR==1{print $1}'
    else
        git ls-remote "$1" "refs/heads/$BRANCH" | awk 'NR==1{print $1}'
    fi
}

main() {
    mkdir -p "$(dirname "$STATE_FILE")"

    # One run at a time: a 3-minute tick must never start on top of a build.
    exec 9>"${STATE_FILE}.lock"
    if ! flock -n 9; then
        log "another deploy run is in progress; skipping"
        exit 0
    fi

    touch "$STATE_FILE"

    # Collect "name sha" for every watched repo. A read failure (network, auth)
    # aborts the whole run without touching state, so we retry next tick.
    local current="" entry name src sha
    for entry in "${REPOS[@]}"; do
        name="${entry%%|*}"
        src="${entry#*|}"
        sha="$(remote_sha "$src" || true)"
        if [ -z "$sha" ]; then
            log "WARN: could not read $name $BRANCH; skipping this run"
            exit 0
        fi
        current+="$name $sha"$'\n'
    done

    if diff -q <(printf '%s' "$current") "$STATE_FILE" >/dev/null 2>&1; then
        log "no changes; already up to date"
        exit 0
    fi

    log "change detected; redeploying:"
    printf '%s' "$current" | sed 's/^/    /'

    cd "$DEPLOY_DIR"
    # The deploy repo is deploy-only (no local edits), so take the remote as-is.
    # This also updates Caddyfile/Dockerfile/compose and this script for next time.
    git fetch -q origin "$BRANCH"
    git reset --hard -q "origin/$BRANCH"

    VERSION="$(git rev-parse --short HEAD)"
    export VERSION

    # --no-cache so the Dockerfile re-clones zola-site and BackdoorBag at HEAD.
    docker compose build --no-cache
    docker compose up -d

    # Only record success after the build and (re)start both succeeded.
    printf '%s' "$current" > "$STATE_FILE"
    log "deploy complete (site-deployment $VERSION)"
}

main "$@"
