# autodeploy (Option A: poll + rebuild)

A systemd **user** timer on the VPS checks every few minutes whether `main`
moved on `zola-site`, `BackdoorBag`, or `site-deployment`. If any did, it
rebuilds and restarts the Caddy container. No GitHub tokens, no inbound ports,
no webhooks — the VPS only reaches out.

## How it works

- `auto-deploy.sh` reads each repo's `main` SHA with `git ls-remote` and
  compares them to the last deployed set in
  `~/.local/state/smavl-deploy/last-deployed`.
- On any change it runs `git reset --hard origin/main` on this repo (to pick up
  Caddyfile / Dockerfile / compose / this script), then
  `docker compose build --no-cache && docker compose up -d`.
- `--no-cache` makes the Dockerfile re-clone `zola-site` and `BackdoorBag` at
  their latest `main`, so content changes land even though they aren't
  submodules.
- A `flock` guards against a new tick starting while a build is still running.

## Install on the VPS (as `web`)

Assumes the repo is checked out at `~/deploy/site-deployment`.

```bash
cd ~/deploy/site-deployment
git pull
chmod +x autodeploy/auto-deploy.sh

# link the unit files (symlinks, so `git pull` keeps them current)
mkdir -p ~/.config/systemd/user
ln -sf ~/deploy/site-deployment/autodeploy/smavl-deploy.service ~/.config/systemd/user/
ln -sf ~/deploy/site-deployment/autodeploy/smavl-deploy.timer   ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now smavl-deploy.timer

# let user services run when you're not logged in (needs root once)
sudo loginctl enable-linger web
```

## Operate

```bash
# when's the next run, when was the last
systemctl --user list-timers smavl-deploy.timer

# follow the logs
journalctl --user -u smavl-deploy.service -f

# force a check/deploy right now
systemctl --user start smavl-deploy.service

# pause / resume automatic deploys
systemctl --user stop smavl-deploy.timer
systemctl --user start smavl-deploy.timer
```

## Notes

- First run always rebuilds (empty state file), then only on changes.
- A network/auth hiccup reading a remote aborts that tick cleanly and retries in
  ~3 min; it never records a half-finished state.
- `restart.sh` still works for a manual, on-demand rebuild.
- Interval lives in `smavl-deploy.timer` (`OnUnitActiveSec`). After editing a
  unit file, run `systemctl --user daemon-reload`.
- To change which repos are watched, edit the `REPOS` array in
  `auto-deploy.sh`.
