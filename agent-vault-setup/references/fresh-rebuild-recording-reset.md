# Fresh rebuild reset pattern for two-VPS credential-broker setups

Use when the operator wants to recreate a credential-broker + agent-runtime deployment from zero after a prior run.

## Default recommendation

Prefer a true clean rebuild over rerunning setup on dirty hosts:

- Delete both old VPS instances.
- Generate a fresh dedicated SSH key or archive the old key before reusing the fixed key name.
- Create fresh cloud SSH-key registration from the new `.pub` value only.
- Create fresh VPS instances and attach them to the same private network.
- Keep private IPs deterministic when the runbook depends on them, e.g. broker `10.0.0.2`, agent `10.0.0.3`.
- Remove stale `known_hosts` entries for old public IPs/DNS before first SSH to new instances.
- Recreate Agent Vault state from scratch: vault, credentials, services, substitutions, agent token.
- Prefer a fresh restricted upstream API key for the run, then revoke it after teardown.

## Safety boundaries

Do not automate destructive cloud deletion unless the exact resource IDs and scope are known. If the user says they will delete and recreate servers, prepare the reset protocol and commands, but do not guess server IDs.

Never overwrite an existing local private key without archiving it first.

Never ask the user to paste these into chat:

- private SSH key
- upstream API key
- Agent Vault master/admin password
- Agent Vault agent token

## Local key patterns

Timestamped fresh key, safest default:

```bash
KEY="$HOME/.ssh/hermes-vps-agent-vault-demo-$(date +%Y%m%d-%H%M%S)"
ssh-keygen -t ed25519 -f "$KEY" -C "$(basename "$KEY")"
chmod 600 "$KEY"
cat "$KEY.pub"
```

Fixed key name only after archiving old material:

```bash
ARCHIVE="$HOME/.ssh/archive-agent-vault-demo-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE"
mv "$HOME/.ssh/hermes-vps-agent-vault-demo" "$ARCHIVE/"
mv "$HOME/.ssh/hermes-vps-agent-vault-demo.pub" "$ARCHIVE/"
ssh-keygen -t ed25519 -f "$HOME/.ssh/hermes-vps-agent-vault-demo" -C "hermes-vps-agent-vault-demo"
chmod 600 "$HOME/.ssh/hermes-vps-agent-vault-demo"
cat "$HOME/.ssh/hermes-vps-agent-vault-demo.pub"
```

## Known-host cleanup

After deleting old servers:

```bash
ssh-keygen -R <old-broker-public-ip>
ssh-keygen -R <old-agent-public-ip>
ssh-keygen -R <old-broker-dns>
ssh-keygen -R <old-agent-dns>
```

## Documentation framing lesson

If the material is meant to be handed to users/agents, keep the runbook operational. Do not include creator/process framing such as video, viewer, creator, narration, or what to show. Only include that language in a separate production script when the explicit deliverable is a script.