# Secure SSH tunneling

Forgejo-iOS defaults to loopback HTTP. Remote access does not require, and this project does not recommend, binding Forgejo directly to the public Internet. An SSH local-port forward lets an administrator use the web UI and HTTP Git through an authenticated SSH connection while Forgejo remains bound to `127.0.0.1` on the iPad.

## Recommended topology

```text
administrator browser / Git
        │ localhost:3000
        │ SSH local forward
        ▼
SSH server on the iPad:22 ── 127.0.0.1:3000 ── Forgejo
```

Keep the Forgejo configuration explicit:

```ini
[server]
HTTP_ADDR = 127.0.0.1
HTTP_PORT = 3000
DISABLE_SSH = true
START_SSH_SERVER = false
```

The SSH service in this document is the device's existing OpenSSH access path, not Forgejo's optional built-in SSH server. Keep Forgejo SSH disabled unless it is separately configured and tested.

## Create a tunnel

From a trusted administrator workstation, use a dedicated SSH key and a known host key:

```sh
ssh -N \
  -o IdentitiesOnly=yes \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -L 3000:127.0.0.1:3000 \
  user@ipad.example
```

Then open `http://127.0.0.1:3000/` locally. The `-L` destination is resolved from the iPad, so Forgejo still sees and uses its loopback listener. To avoid a local port conflict, choose another local port, for example `-L 13000:127.0.0.1:3000`.

For Git over HTTP, use the forwarded local endpoint only while the tunnel is active, for example:

```sh
git clone http://127.0.0.1:3000/OWNER/REPOSITORY.git
```

Use Forgejo credentials or tokens according to Forgejo's normal authentication rules. Do not put passwords or tokens in the SSH command line or shell history.

## Harden the SSH boundary

- Use a dedicated non-root SSH account where possible; do not expose a root login.
- Prefer public-key authentication, `IdentitiesOnly=yes`, and a separately verified `known_hosts` entry.
- Restrict the SSH account with the device's OpenSSH configuration and firewall/package controls where available.
- Keep private keys on the administrator workstation with restrictive permissions; never commit them or copy them into the Forgejo runtime tree.
- Bind the tunnel to loopback on the workstation unless there is a deliberate, separately protected shared-client design. Do not use `-g` or `-R` casually.
- Treat the SSH account, jailbreak root access, and the iPad as part of the security boundary. The tunnel encrypts transport; it does not provide server hardening or protect secrets from a root-capable process on the device.
- Check the effective listener with the device's `netstat` equivalent and keep Forgejo off `0.0.0.0`, `::`, and `*` for the local-only profile.

For backups and broader deployment security, read [`SECURITY.md`](SECURITY.md). For the tested device limits, read [`COMPATIBILITY.md`](COMPATIBILITY.md).
