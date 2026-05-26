# Agent Vault + Hermes two-VPS setup — agent execution PRD/runbook

Status: agent-facing execution contract
Audience: a Hermes agent operating with SSH access and a non-developer human available for HITL checkpoints
Source guide: `prds/agent-vault-step-by-step.md`
Fresh rebuild protocol: `prds/agent-vault-fresh-rebuild.md`
Execution checklist: `prds/agent-vault-checklist.md`
Primary verdict: the human-facing guide explains the setup, but it is not strict enough for a random agent. Agents need a stricter input contract, hard stop points, exact verification gates, and “do not print secrets” rules. This file is that stricter version.

Before executing any server mutation, the agent must open `prds/agent-vault-checklist.md`, work through it phase by phase, and record evidence for each completed checkpoint. If the checklist and this runbook disagree, stop and resolve the mismatch before continuing.

---

## Problem Statement

A non-developer can hand a long Agent Vault + Hermes VPS guide to Hermes and expect help, but the guide is written as a human tutorial. That is risky for autonomous execution because agents can accidentally skip prerequisites, ask for secrets in chat, bind admin surfaces publicly, confuse Agent Vault’s two “Agents” screens, or test the happy path without proving the credential-broker architecture actually works.

The user needs a repeatable agent-runbook where Hermes can SSH into two VPS servers, configure the broker/runtime pieces, pause only for human-owned secrets and cloud-console actions, then verify the setup end-to-end.

## Solution

Create an agent-facing PRD/runbook for recreating the two-VPS setup:

- `av-broker` runs Agent Vault on private IP `10.0.0.2`.
- `hermes-vps` runs Hermes Agent on private IP `10.0.0.3`.
- Agent Vault UI/API listens on `10.0.0.2:14321`.
- Agent Vault MITM proxy listens on `10.0.0.2:14322`.
- The real `OPENROUTER_API_KEY` lives only inside Agent Vault Credentials.
- Hermes stores only `OPENROUTER_API_KEY=__OPENROUTER_API_KEY__`.
- Agent Vault service `openrouter` matches `openrouter.ai/api/*`.
- Authentication is `Passthrough`.
- Substitution replaces `__OPENROUTER_API_KEY__` on header surface only, with value of credential name `OPENROUTER_API_KEY`.
- Hermes is started with `agent-vault run -- hermes`, not plain `hermes`.

The agent should automate package installs, SSH verification, private-network checks, config writes, health checks, and non-secret validation. The human owns cloud billing/provisioning, passwords, master password, owner account, OpenRouter key entry, and Agent Vault agent-token creation/paste.

## User Stories

1. As a non-developer, I want to give Hermes a guide and public server details so Hermes can do the terminal work for me.
2. As a non-developer, I want Hermes to pause only when a real human action is required, not every time the guide gets slightly technical.
3. As a security-conscious operator, I want the real OpenRouter key stored only in Agent Vault, not on the Hermes VPS.
4. As a user, I want human-owned actions clearly separated from agent-owned actions so secrets stay private.
5. As Hermes, I need an explicit input contract so I do not guess IPs, key paths, vault names, or service names.
6. As Hermes, I need exact commands and expected outputs so I can verify each stage before moving on.
7. As Hermes, I need hard stop rules for secrets so I do not ask the user to paste API keys, passwords, private keys, or agent tokens into chat.
8. As Hermes, I need known failure fixes for SSH, host pattern mismatches, missing token env, wrong Agent Vault screen, and plain-Hermes startup.
9. As the final operator, I need proof that traffic routes through Agent Vault, not just proof that Hermes replied once.

## Implementation Decisions

### 1. Input contract

Before mutating any server, Hermes must collect or create this contract:

```text
SSH_KEY_PATH=~/.ssh/hermes-vps-agent-vault-demo
AV_BROKER_PUBLIC_IP=<public IPv4 or DNS for av-broker>
HERMES_VPS_PUBLIC_IP=<public IPv4 or DNS for hermes-vps>
AV_BROKER_PRIVATE_IP=10.0.0.2
HERMES_VPS_PRIVATE_IP=10.0.0.3
SSH_USER=root
VAULT_NAME=prod
AGENT_NAME=hermes-vps
OPENROUTER_CREDENTIAL_NAME=OPENROUTER_API_KEY
OPENROUTER_PLACEHOLDER=__OPENROUTER_API_KEY__
OPENROUTER_HOST_PATTERN=openrouter.ai/api/*
HERMES_PROVIDER=openrouter
HERMES_BASE_URL=https://openrouter.ai/api/v1
HERMES_MODEL=openai/gpt-4o-mini
```

If `SSH_KEY_PATH` does not exist, Hermes may create it and print only the public key.

Hermes must not continue until the human confirms:

```text
- the public key was uploaded to the cloud provider
- both VPS servers exist
- both VPS servers are attached to the same private network
- av-broker has private IP 10.0.0.2
- hermes-vps has private IP 10.0.0.3
```

### 2. Non-negotiable safety rules

Hermes must follow these without improvising:

1. Never ask the user to paste a private SSH key into chat.
2. Never ask the user to paste the OpenRouter API key into chat.
3. Never ask the user to paste the Agent Vault master password or admin password into chat.
4. Never print the Agent Vault agent token.
5. Never write the real OpenRouter key to `hermes-vps`.
6. Never bind Agent Vault UI/API/proxy to `0.0.0.0` for this setup.
7. Never expose Agent Vault UI publicly; use an SSH tunnel.
8. Never proceed past a failed SSH or private-network check.
9. Never treat a Hermes reply as sufficient proof; verify broker health, listeners, service discovery, placeholder config, and proxy path.
10. Never use plain `hermes` for the final test; use `agent-vault run -- hermes` or `agent-vault run -- hermes chat ...`.

### 3. Ownership split

| Step | Owner | Why |
|---|---|---|
| Create local SSH key if missing | Hermes | Safe; only public key is shared |
| Upload public SSH key to Hetzner/cloud | Human | Cloud-console/billing identity |
| Create two VPS servers/private network | Human | Billing and infrastructure ownership |
| Verify SSH to both VPS boxes | Hermes | Deterministic terminal check |
| Verify private IPs and private ping | Hermes | Deterministic network check |
| Install Agent Vault on broker | Hermes | Deterministic package/install work |
| Start Agent Vault in `tmux` | Hermes | Deterministic process start |
| Enter Agent Vault master/admin credentials | Human | Secret/identity boundary |
| Open SSH tunnel to Agent Vault UI | Hermes or Human | Safe if no secret printed |
| Create vault `prod` | Human guided by Hermes | UI action; no secret except session auth |
| Add real OpenRouter credential | Human only | Secret boundary |
| Add OpenRouter service | Human guided by Hermes | UI currently easiest; values are non-secret |
| Create Agent Vault agent `hermes-vps` | Human guided by Hermes | Token generated in UI |
| Put Agent Vault token on `hermes-vps` | Human or Hermes with redaction discipline | Token is sensitive; do not chat-print |
| Install Hermes on `hermes-vps` | Hermes | Deterministic install work |
| Write placeholder `.env` | Hermes | Must not contain real key |
| Configure Hermes model/provider | Hermes | Deterministic config work |
| Run final test through Agent Vault | Hermes | Deterministic verification |
| Produce final report | Hermes | Artifact-driven finish |

### 4. Automation sequence

Use this exact sequence. Do not jump ahead.

#### Phase A — Prepare SSH key

Run locally:

```bash
install -d -m 700 ~/.ssh
if [ ! -f ~/.ssh/hermes-vps-agent-vault-demo ]; then
  ssh-keygen -t ed25519 -f ~/.ssh/hermes-vps-agent-vault-demo -C hermes-vps-agent-vault-demo -N ""
fi
chmod 600 ~/.ssh/hermes-vps-agent-vault-demo
chmod 644 ~/.ssh/hermes-vps-agent-vault-demo.pub
ssh-keygen -lf ~/.ssh/hermes-vps-agent-vault-demo.pub
printf '\nPUBLIC KEY TO UPLOAD:\n'
cat ~/.ssh/hermes-vps-agent-vault-demo.pub
```

HITL stop:

```text
Upload the PUBLIC KEY line to Hetzner/cloud. Create two Ubuntu VPS servers with this key and a private network:
- av-broker: 10.0.0.2
- hermes-vps: 10.0.0.3
Then provide only the two public IPs/DNS names. Do not paste private keys or passwords.
```

#### Phase B — Verify SSH access

Set variables locally:

```bash
SSH_KEY="$HOME/.ssh/hermes-vps-agent-vault-demo"
AV_BROKER_PUBLIC_IP="<AV_BROKER_PUBLIC_IP>"
HERMES_VPS_PUBLIC_IP="<HERMES_VPS_PUBLIC_IP>"
```

Verify broker:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes root@"$AV_BROKER_PUBLIC_IP" 'hostname; hostname -I; . /etc/os-release && echo "$PRETTY_NAME"'
```

Verify Hermes VPS:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes root@"$HERMES_VPS_PUBLIC_IP" 'hostname; hostname -I; . /etc/os-release && echo "$PRETTY_NAME"'
```

Expected:

```text
- SSH exits 0 for both servers
- each output includes the expected hostname/IP list
- no password prompt
```

If SSH prompts for a password, stop. Do not continue.

#### Phase C — Verify private networking

From broker to Hermes:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" 'ping -c 3 10.0.0.3'
```

From Hermes to broker:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" 'ping -c 3 10.0.0.2'
```

Expected:

```text
3 packets transmitted, 3 received
```

If private ping fails, stop and tell the human to fix the private network attachment/IP assignment in Hetzner/cloud.

#### Phase D — Install Agent Vault on `av-broker`

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl tar tmux jq net-tools iproute2
curl --proto "=https" --proto-redir "=https" --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
agent-vault version
'
```

Expected:

```text
agent-vault version prints successfully
```

#### Phase E — Start Agent Vault privately in `tmux`

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" '
set -euo pipefail
if tmux has-session -t av 2>/dev/null; then
  tmux kill-session -t av
fi
tmux new-session -d -s av "AGENT_VAULT_ADDR=http://10.0.0.2:14321 agent-vault server --host 10.0.0.2 --port 14321 --mitm-port 14322"
tmux ls
'
```

HITL stop:

```text
Agent Vault may be waiting inside tmux for first-run setup.
Open your own terminal and run:

ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes root@<AV_BROKER_PUBLIC_IP>
tmux attach -t av

Enter the Agent Vault master password/admin setup directly there.
Do not paste those passwords into chat.
Detach with: Ctrl-b then d
Then tell Hermes: done.
```

#### Phase F — Verify broker health and private binding

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" '
set -euo pipefail
curl -fsS http://10.0.0.2:14321/health
ss -ltnp | grep -E "10\.0\.0\.2:(14321|14322)"
'
```

Expected:

```json
{"status":"ok"}
```

And listener output must include:

```text
10.0.0.2:14321
10.0.0.2:14322
```

If it shows `0.0.0.0:14321` or `0.0.0.0:14322`, stop and restart Agent Vault bound to `10.0.0.2`.

#### Phase G — Open UI tunnel

From the operator machine:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes -L 14321:10.0.0.2:14321 root@<AV_BROKER_PUBLIC_IP> -N
```

Leave that terminal open. Open:

```text
http://localhost:14321
```

#### Phase H — Human configures Agent Vault UI

HITL stop. Human does these UI actions:

1. Log in with the Agent Vault admin account.
2. Create vault:

```text
Vault name: prod
```

3. Add credential:

```text
Credential name: OPENROUTER_API_KEY
Credential value: <real OpenRouter API key>
```

4. Add service:

```text
Name: openrouter
Host Pattern*: openrouter.ai/api/*
Authentication: Passthrough
URL substitution:
  Replace: __OPENROUTER_API_KEY__
  Surface: header only
  with value of: OPENROUTER_API_KEY
```

5. Create agent from the global Agents page:

```text
http://localhost:14321/agents
```

Use:

```text
Agent name: hermes-vps
Vault access: prod
Role: proxy
```

Critical UI gotcha:

```text
If the screen says “AI agents with access to this vault”, you are in the vault-level Agents tab. That screen does not create a new instance agent. Go to /agents globally.
```

6. Copy the connect snippet/token, but do not paste it into chat.

#### Phase I — Install Hermes and Agent Vault CLI on `hermes-vps`

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl tar git tmux jq net-tools iproute2
curl --proto "=https" --proto-redir "=https" --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup --skip-browser
agent-vault version
hermes --version
'
```

#### Phase J — Configure Hermes placeholder env and OpenRouter provider

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
mkdir -p /root/.hermes
install -m 600 /dev/null /root/.hermes/.env
cat > /root/.hermes/.env <<"EOF"
OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
EOF
chmod 600 /root/.hermes/.env
hermes config set model.provider openrouter
hermes config set model.default openai/gpt-4o-mini
hermes config set model.base_url https://openrouter.ai/api/v1
printf "Hermes env placeholder check: "
grep -q "^OPENROUTER_API_KEY=__OPENROUTER_API_KEY__$" /root/.hermes/.env && echo OK
'
```

Expected:

```text
Hermes env placeholder check: OK
```

Hermes must not write a real `sk-or-v1-...` key anywhere on this host.

#### Phase K — Put Agent Vault runtime token on `hermes-vps`

Preferred HITL method: human pastes the Agent Vault connect snippet directly into a root shell on `hermes-vps`, not into chat.

Human terminal:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes root@<HERMES_VPS_PUBLIC_IP>
install -m 600 /dev/null /root/.agent-vault-env
cat > /root/.agent-vault-env <<'EOF'
AGENT_VAULT_ADDR=http://10.0.0.2:14321
AGENT_VAULT_TOKEN=<token from Agent Vault UI>
AGENT_VAULT_VAULT=prod
EOF
chmod 600 /root/.agent-vault-env
```

Then human says only:

```text
done
```

Hermes verifies without printing the token:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
. /root/.agent-vault-env
test "$AGENT_VAULT_ADDR" = "http://10.0.0.2:14321"
test "$AGENT_VAULT_VAULT" = "prod"
test -n "$AGENT_VAULT_TOKEN"
echo AGENT_VAULT_ENV_OK
'
```

Expected:

```text
AGENT_VAULT_ENV_OK
```

#### Phase L — Discover vault contents from `hermes-vps`

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
. /root/.agent-vault-env
agent-vault vault discover --vault prod
'
```

Expected output shape:

```text
Vault: prod
Services
openrouter    openrouter.ai/api/*
Available Credentials
OPENROUTER_API_KEY
```

If it shows `openrouter.ai/api/` without `*`, stop and have the human fix the service Host Pattern in the UI.

#### Phase M — Final non-interactive Hermes test through Agent Vault

Use a one-shot Hermes command so the agent can verify without babysitting an interactive TUI:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
. /root/.agent-vault-env
agent-vault run -- hermes chat -Q -q "Reply with exactly: ok"
'
```

Expected:

```text
ok
```

If this fails, do not “try random models.” Check the mismatch table first.

#### Phase N — Optional interactive session start

For an interactive operator session:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes root@<HERMES_VPS_PUBLIC_IP>
. /root/.agent-vault-env
agent-vault run -- hermes
```

Inside Hermes:

```text
say ok
```

Expected: Hermes replies.

#### Phase O — Firewall hardening default: Tailscale, with temporary break-glass SSH

Default recommendation: use Tailscale, not long-term public-IP allowlisting.

Option A, public-IP allowlist, is acceptable only as a temporary break-glass path during setup:

```text
Allow TCP 22 from:
- the operator laptop's current public IP
- the automation/operator VPS public IP, if a remote Hermes host needs direct SSH
Deny all other public inbound traffic.
```

Why this is not the default: home/office/VPN/mobile public IPs change, agent host egress IPs can change, and the rule becomes either brittle or too broad. Brittle security is just future lockout cosplay.

Option B, Tailscale, is the default:

```text
Tailnet members:
- operator laptop / M4
- av-broker
- hermes-vps
- any separate automation host that must SSH into the VPS boxes
```

Install Tailscale on both VPS boxes:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" '
set -euo pipefail
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --hostname=av-broker --ssh --accept-dns=false
'

ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --hostname=hermes-vps --ssh --accept-dns=false
'
```

HITL stop:

```text
Each `tailscale up` may print an auth URL. Open the URL, approve the node in the Tailscale admin UI, and do not paste auth keys into chat.
```

Verify Tailscale before closing public SSH:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" 'tailscale status; tailscale ip -4'
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" 'tailscale status; tailscale ip -4'
```

Then verify SSH over Tailscale from the operator machine:

```bash
ssh root@<AV_BROKER_TAILSCALE_IP> 'hostname; tailscale ip -4'
ssh root@<HERMES_VPS_TAILSCALE_IP> 'hostname; tailscale ip -4'
```

Only after SSH over Tailscale works, apply host firewall rules.

On `av-broker`:

```bash
ssh root@<AV_BROKER_TAILSCALE_IP> '
set -euo pipefail
apt-get update -y
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0 to any port 22 proto tcp
ufw allow from 10.0.0.3 to any port 14321 proto tcp
ufw allow from 10.0.0.3 to any port 14322 proto tcp
ufw --force enable
ufw status verbose
'
```

On `hermes-vps`:

```bash
ssh root@<HERMES_VPS_TAILSCALE_IP> '
set -euo pipefail
apt-get update -y
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0 to any port 22 proto tcp
ufw --force enable
ufw status verbose
'
```

Keep Agent Vault bound to `10.0.0.2`. Do not rebind it to public `0.0.0.0` just because Tailscale exists.

For UI access after public SSH is closed, use the SSH tunnel over Tailscale:

```bash
ssh -L 14321:10.0.0.2:14321 root@<AV_BROKER_TAILSCALE_IP> -N
```

Then open:

```text
http://localhost:14321
```

If using Hetzner Cloud Firewall as well, keep it simple:

```text
Inbound public:
- allow UDP 41641 for Tailscale direct connections, optional but recommended
- optionally keep temporary TCP 22 from the operator's current public IP until Tailscale SSH is proven
- deny all other inbound public traffic
Outbound:
- allow all, because Agent Vault must reach OpenRouter and Tailscale coordination/DERP
```

After Tailscale SSH is proven, remove the temporary public TCP 22 allowlist. Keep Hetzner rescue console as the real break-glass path.

## Testing Decisions

### Verification ladder

Hermes must verify every rung:

1. SSH key exists and private key permissions are `600`.
2. SSH works to both public IPs with `BatchMode=yes`.
3. Private ping works both ways.
4. Agent Vault installs and `agent-vault version` prints on broker.
5. Agent Vault starts in `tmux`.
6. Human completes master/admin setup in `tmux`.
7. Broker health returns `{"status":"ok"}` on `10.0.0.2:14321`.
8. `ss` shows listeners on `10.0.0.2:14321` and `10.0.0.2:14322`, not public wildcard.
9. UI tunnel reaches `http://localhost:14321`.
10. Human creates vault, credential, service, and global agent.
11. Agent Vault CLI and Hermes install on `hermes-vps`.
12. `/root/.hermes/.env` contains only `OPENROUTER_API_KEY=__OPENROUTER_API_KEY__`.
13. Hermes config points to OpenRouter and `https://openrouter.ai/api/v1`.
14. `/root/.agent-vault-env` exists, has correct address/vault, and has a non-empty token without printing it.
15. `agent-vault vault discover --vault prod` shows `openrouter.ai/api/*` and `OPENROUTER_API_KEY`.
16. `agent-vault run -- hermes chat -Q -q "Reply with exactly: ok"` returns `ok`.
17. Tailscale is installed and authenticated on both VPS boxes if firewall hardening is requested.
18. SSH over Tailscale works to both VPS boxes before public SSH is closed.
19. `ufw status verbose` allows SSH on `tailscale0`, allows broker ports `14321/14322` only from `10.0.0.3`, and denies other public inbound traffic.
20. Agent Vault still answers `/health` from `hermes-vps` after firewall rules are enabled.

### Secret leak checks

Run on `hermes-vps`:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" '
set -euo pipefail
if grep -R "sk-or-v1-" /root/.hermes /root/.config 2>/dev/null; then
  echo "FAIL_REAL_OPENROUTER_KEY_FOUND"
  exit 1
fi
echo "NO_REAL_OPENROUTER_KEY_FOUND_IN_HERMES_CONFIG"
'
```

Expected:

```text
NO_REAL_OPENROUTER_KEY_FOUND_IN_HERMES_CONFIG
```

Do not grep the entire filesystem unless needed; logs can be noisy and slow.

### Revocation proof, optional verification

If the material claims revocability, prove it:

1. Human rotates/deletes the `hermes-vps` agent token in Agent Vault UI.
2. Hermes reruns the one-shot command and expects failure.
3. Human writes the new token into `/root/.agent-vault-env`.
4. Hermes reruns the one-shot command and expects `ok`.

Do not perform this if the user only asked for the basic setup and is short on time.

## Failure Fixes

### SSH asks for password

Likely cause: wrong key file, key not uploaded, or cloud server created before key selection.

Run:

```bash
ssh-keygen -lf ~/.ssh/hermes-vps-agent-vault-demo.pub
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes -o BatchMode=yes root@<SERVER_PUBLIC_IP> 'echo SSH_OK'
```

If still failing, human must verify the uploaded `.pub` key in Hetzner/cloud. Do not continue.

### Private ping fails

Likely cause: servers are not on the same private network or private IPs differ.

Ask human to verify:

```text
av-broker private IP: 10.0.0.2
hermes-vps private IP: 10.0.0.3
same private network: 10.0.0.0/24
```

Do not hack around this with public IP broker traffic.

### Agent Vault health fails

Check tmux:

```bash
ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" 'tmux ls; tmux capture-pane -t av -p | tail -80'
```

If first-run setup is waiting, human must attach and finish it.

### UI tunnel does not open

Re-run tunnel from operator machine:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes -L 14321:10.0.0.2:14321 root@<AV_BROKER_PUBLIC_IP> -N
```

Then open:

```text
http://localhost:14321
```

If port `14321` is already used locally, use:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes -L 114321:10.0.0.2:14321 root@<AV_BROKER_PUBLIC_IP> -N
```

Then open:

```text
http://localhost:114321
```

### Wrong Agent Vault Agents page

If the page says:

```text
AI agents with access to this vault
```

that is the wrong screen for creating the instance agent. Use:

```text
http://localhost:14321/agents
```

### `agent-vault vault discover` misses OpenRouter

Check UI service values:

```text
Service name: openrouter
Host Pattern*: openrouter.ai/api/*
Authentication: Passthrough
Replace: __OPENROUTER_API_KEY__
Surface: header only
with value of: OPENROUTER_API_KEY
```

The `with value of` field takes the credential name, not the real key. If you paste `sk-or-v1-...` there, Agent Vault complains because it expects an upper-snake-case key name. Petty, but correct.

### Hermes fails when started normally

If the command was:

```bash
hermes
```

that is the bug. Use:

```bash
. /root/.agent-vault-env
agent-vault run -- hermes
```

or for one-shot verification:

```bash
. /root/.agent-vault-env
agent-vault run -- hermes chat -Q -q "Reply with exactly: ok"
```

### Token missing on `hermes-vps`

Verify without printing:

```bash
test -f /root/.agent-vault-env && . /root/.agent-vault-env && test -n "$AGENT_VAULT_TOKEN" && echo TOKEN_SET || echo TOKEN_MISSING
```

If missing, human must paste a fresh connect snippet/token into `/root/.agent-vault-env` on the remote shell.

## Out of Scope

- Full production hardening.
- Cloud-provider API automation for creating Hetzner resources.
- Public exposure of Agent Vault UI.
- Storing real OpenRouter keys on `hermes-vps`.
- Automating secret entry through chat.
- Multi-provider failover.
- Telegram gateway setup.
- Firewall egress lockdown before the proxy path is proven.
- Kubernetes, Docker Compose, or load-balanced Agent Vault.

## Further Notes

### Execution notes

This runbook is the agent control plane:

- exact preflight contract
- mandatory stop points
- no-secret rules
- executable command blocks
- expected outputs
- failure branches
- final report template

The agent must check off each phase with evidence before proceeding. The user handles only cloud-console actions, credentials, passwords, and explicit approval gates.

### Distribution-safe boundaries

Safe to expose:

```text
- public key generation
- cloud server creation with secrets hidden
- agent executing SSH/package/config commands
- Agent Vault UI screens after secrets are hidden
- service settings: openrouter.ai/api/*, Passthrough, header substitution
- Hermes final test through agent-vault run
```

Never expose:

```text
- private SSH key contents
- real OpenRouter key
- Agent Vault master password
- Agent Vault admin password
- Agent Vault agent token
```

### Final report template

Hermes should finish with this structure:

```text
Agent Vault + Hermes VPS setup report

Inputs used:
- broker public host: <redacted or shown if user permits>
- Hermes public host: <redacted or shown if user permits>
- SSH key path: ~/.ssh/hermes-vps-agent-vault-demo
- broker private IP: 10.0.0.2
- Hermes private IP: 10.0.0.3

Completed:
- SSH verified to both VPS servers: yes/no
- Private networking verified both ways: yes/no
- Agent Vault installed on av-broker: yes/no
- Agent Vault bound privately on 10.0.0.2:14321 and 10.0.0.2:14322: yes/no
- Vault prod created by human: yes/no
- OpenRouter credential added by human: yes/no, value not seen
- OpenRouter service configured: yes/no
- Global agent hermes-vps created: yes/no
- Hermes installed on hermes-vps: yes/no
- Hermes placeholder env written: yes/no
- Agent Vault env token present: yes/no, token not printed
- Discovery shows openrouter.ai/api/* and OPENROUTER_API_KEY: yes/no
- Final Hermes one-shot through Agent Vault returned ok: yes/no

Files changed on hermes-vps:
- /root/.hermes/.env
- /root/.agent-vault-env
- Hermes config under /root/.hermes/

Secrets handling:
- real OpenRouter key was not pasted into chat
- real OpenRouter key was not written to Hermes host
- private SSH key was not pasted into chat
- Agent Vault token was not printed

Remaining risks:
- baseline setup is not full production hardening
- systemd/gateway persistence not configured unless separately requested
- egress lockdown not applied unless separately requested
```

## Decisions Log

Q: Should the human guide be enough for an autonomous Hermes agent?
A: No, not by itself.
Why: It is written for human comprehension, while autonomous execution needs an explicit contract, stop points, and verification gates.

Q: Should Hermes fully automate cloud provisioning?
A: No for this version.
Why: Cloud provisioning includes billing/identity choices and is outside the source guide’s safe baseline.

Q: Should Hermes create the SSH key?
A: Yes, if it is missing.
Why: Creating a dedicated local key and printing only the `.pub` key is safe and reduces non-developer friction.

Q: Should the private key ever be shown or uploaded?
A: No.
Why: Only the public key belongs in Hetzner/cloud; leaking the private key compromises both servers.

Q: Should Agent Vault bind to public interfaces for convenience?
A: No.
Why: The UI/API and MITM proxy should remain on the private network; access the UI through an SSH tunnel.

Q: Should Hermes ask for the OpenRouter key in chat?
A: No.
Why: The real upstream key belongs only in Agent Vault Credentials, entered by the human in the UI.

Q: Should Hermes ask for the Agent Vault master password/admin password in chat?
A: No.
Why: Those credentials define vault ownership and must remain human-owned.

Q: Should Hermes use Agent Vault’s global `/agents` page or the vault-level Agents tab to create `hermes-vps`?
A: Use the global `/agents` page.
Why: The vault-level tab only grants vault access to existing instance agents and caused confusion in the live setup.

Q: What exact OpenRouter host pattern should be used?
A: `openrouter.ai/api/*`.
Why: The final `*` is required to match real OpenRouter API paths under `/api/`.

Q: What should the OpenRouter substitution target be?
A: The credential name `OPENROUTER_API_KEY`, not the real `sk-or-v1-...` value.
Why: Agent Vault expects a credential key/name and retrieves the encrypted value internally.

Q: Should OpenRouter be configured as typed bearer auth or passthrough?
A: Use `Authentication: Passthrough` for this placeholder flow.
Why: Hermes sends the placeholder key, and Agent Vault swaps that placeholder in the header.

Q: Should final verification use interactive Hermes only?
A: No.
Why: `hermes chat -Q -q` through `agent-vault run --` gives a deterministic agent-verifiable test; interactive Hermes is only for a manual operator session afterward.

Q: Is a single Hermes reply enough proof?
A: No.
Why: A reply proves the model call worked, not that the credential broker path, private binding, service matching, and secret isolation are correct.

Q: Should firewall egress lockdown be included now?
A: No.
Why: Lockdown before proving the proxy path creates a secure brick; add it only after the baseline works.
