# remote-desktop

A short-lived GitHub Mac or Windows computer that you can see and control from your own computer.
Use it to test software on a clean machine. The connection goes through Tailscale (a private network).

## Start
```
gh workflow run remote-desktop.yml -R rsvishalsingh93/remote-desktop -f os=macos -f minutes=60
gh run list -R rsvishalsingh93/remote-desktop -L 1
```
Open the run log. The step "Enable Screen Sharing" or "Enable Remote Desktop" shows the address and the user name.

- Mac: open Screen Sharing and connect to the address. User: `runner`.
- Windows: open Windows App and connect to the address. User: `runneradmin`.
- Password: the `RD_PASSWORD` secret.

## Stop
```
gh run cancel <run-id> -R rsvishalsingh93/remote-desktop
```

## Secrets
- `TAILSCALE_GITHUB_AUTH_KEY`: Tailscale auth key (reusable, ephemeral).
- `RD_PASSWORD`: login password for the remote user (12+ characters, with capital letters, small letters, numbers and a symbol).
