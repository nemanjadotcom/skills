# Agent Vault + Hermes on two VPS servers — step-by-step human guide

Status: working setup runbook
Audience: non-developers who want Hermes running on a VPS without manually walking every terminal step
Scope: Agent Vault broker on one server, Hermes Agent on another server, OpenRouter credential brokered through Agent Vault

---

## The idea in plain English

We want Hermes Agent to run on a VPS, but we do not want the real OpenRouter API key sitting on that Hermes VPS.

So we use two servers:

| Server | Private IP | Job |
|---|---:|---|
| `av-broker` | `10.0.0.2` | Runs Agent Vault and stores the real API key |
| `hermes-vps` | `10.0.0.3` | Runs Hermes Agent with only fake placeholder credentials |

Hermes sends requests with a placeholder key.

Agent Vault sees the request, swaps the placeholder for the real key, forwards the request to OpenRouter, and keeps the real key off the Hermes server.

That is the whole trick.

---

## Architecture

```text
Your laptop
  |
  | SSH tunnel to Agent Vault UI
  v
av-broker
  private IP: 10.0.0.2
  Agent Vault UI/API: 10.0.0.2:14321
  Agent Vault proxy:  10.0.0.2:14322
  stores real OPENROUTER_API_KEY
  |
  | private network only
  v
hermes-vps
  private IP: 10.0.0.3
  runs Hermes Agent
  stores only OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
```

Public IPs are only for SSH. The Agent Vault UI should not be exposed publicly.

---

## What we actually built

We provisioned two Hetzner VPS boxes:

1. `av-broker`
   - Agent Vault installed.
   - Agent Vault launched inside `tmux`.
   - Bound only to private IP `10.0.0.2`.
   - UI/API on port `14321`.
   - MITM proxy on port `14322`.

2. `hermes-vps`
   - Agent Vault CLI installed.
   - Hermes Agent installed.
   - Hermes configured to use OpenRouter.
   - Hermes `.env` uses a placeholder OpenRouter key, not the real key.
   - Hermes is started with `agent-vault run -- hermes`.

We verified the broker was healthy:

```text
Agent Vault server listening on http://10.0.0.2:14321
Agent Vault transparent proxy listening on 10.0.0.2:14322
/health returned {"status":"ok"}
```

We verified Hermes worked through Agent Vault by starting it with:

```bash
agent-vault run -- hermes
```

Then sending a small test prompt.

---

## Step 1 — Create a fresh SSH key for this setup

Assume the user does not already have an SSH key. Make a dedicated key just for this Agent Vault setup.

On your Mac or laptop, run:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/agent_vault_demo_ed25519 -C "agent-vault-demo"
```

When it asks for a passphrase, press Enter twice for no passphrase if this is a temporary setup key. For a real long-lived server, use a passphrase.

This creates two files:

```text
~/.ssh/agent_vault_demo_ed25519      private key — keep this secret
~/.ssh/agent_vault_demo_ed25519.pub  public key — upload this to Hetzner
```

Lock down the private key permissions:

```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/agent_vault_demo_ed25519 && chmod 644 ~/.ssh/agent_vault_demo_ed25519.pub
```

Print the public key:

```bash
cat ~/.ssh/agent_vault_demo_ed25519.pub
```

Copy the full line that starts with:

```text
ssh-ed25519
```

Upload that public key in Hetzner:

```text
Hetzner Cloud Console → Project → Security → SSH Keys → Add SSH Key
```

Paste the `.pub` key, name it something obvious like:

```text
agent-vault-demo
```

Then select that SSH key when creating both VPS servers.

Important: the Hetzner SSH key name is just a label. It is not the filename on your Mac.

In our run, this caused confusion. The working local key file was:

```bash
~/.ssh/agent_vault_demo_ed25519
```

So every SSH command needed:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<SERVER_PUBLIC_IP>
```

Do not run the key file directly.

Wrong:

```bash
~/.ssh/agent_vault_demo_ed25519
```

That produces:

```text
permission denied
```

Right:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<SERVER_PUBLIC_IP>
```

The key is an input to SSH, not a command.

Never paste the private key into Hetzner, chat, docs, screenshots, or shared material. Only upload the `.pub` file.

---

## Step 2 — Create the two VPS servers

Create two Ubuntu VPS servers in Hetzner.

Use a private network:

```text
10.0.0.0/24
```

Assign:

```text
av-broker   → 10.0.0.2
hermes-vps  → 10.0.0.3
```

Use the same SSH public key for both servers.

From your laptop, confirm SSH works:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<AV_BROKER_PUBLIC_IP>
```

And:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<HERMES_VPS_PUBLIC_IP>
```

Do not continue until SSH works. Seriously. Everything after this depends on it.

---

## Step 3 — Install Agent Vault on `av-broker`

SSH into `av-broker`:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<AV_BROKER_PUBLIC_IP>
```

Install basics:

```bash
apt-get update -y && apt-get install -y ca-certificates curl tar tmux jq net-tools iproute2
```

Install Agent Vault:

```bash
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
```

Check it installed:

```bash
agent-vault version
```

---

## Step 4 — Start Agent Vault inside `tmux`

Start Agent Vault in `tmux` so it keeps running after SSH disconnects:

```bash
tmux new-session -d -s av 'AGENT_VAULT_ADDR=http://10.0.0.2:14321 agent-vault server --host 10.0.0.2 --port 14321 --mitm-port 14322'
```

Attach to the session:

```bash
tmux attach -t av
```

On first run, Agent Vault asks for:

1. master password
2. admin email
3. admin password

Enter those inside the `tmux` session.

Do not paste passwords into chat or docs.

Detach from `tmux` with:

```text
Ctrl-b then d
```

Gotcha: the first-run password/admin prompts happen inside `tmux`, not in your browser.

---

## Step 5 — Verify Agent Vault is bound privately

On `av-broker`, run:

```bash
curl -fsS http://10.0.0.2:14321/health
```

Expected:

```json
{"status":"ok"}
```

Check listeners:

```bash
ss -ltnp | grep -E '14321|14322'
```

Expected shape:

```text
10.0.0.2:14321
10.0.0.2:14322
```

This matters. You want Agent Vault on the private network, not exposed to the public internet.

---

## Step 6 — Open the Agent Vault UI from your laptop

From your laptop, open an SSH tunnel:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes -L 14321:10.0.0.2:14321 root@<AV_BROKER_PUBLIC_IP> -N
```

That terminal will look stuck. Good. Leave it open.

Now open this in your browser:

```text
http://localhost:14321
```

Log in with the admin account you created during Agent Vault first-run setup.

---

## Step 7 — Create the `prod` vault

In the Agent Vault UI:

```text
Vaults → New vault → prod → Create
```

We used:

```text
prod
```

as the vault name.

---

## Step 8 — Add the OpenRouter credential

In Agent Vault:

```text
prod vault → Credentials → Add credential
```

Create this credential:

```text
Name: OPENROUTER_API_KEY
Value: your real sk-or-v1-... key
```

The real OpenRouter key belongs only in Credentials.

It should not be pasted into Services.

It should not be written into Hermes `.env`.

It should not be pasted into chat.

---

## Step 9 — Add the OpenRouter service

In Agent Vault:

```text
prod vault → Services → Add service
```

Use exactly:

```text
Name: openrouter
Host Pattern*: openrouter.ai/api/*
Authentication: Passthrough
```

Then under URL Substitutions:

```text
Replace: __OPENROUTER_API_KEY__
Surface: header only
with value of: OPENROUTER_API_KEY
```

Untick:

```text
path
query
```

Only `header` should be selected.

This is what we got wrong during the live setup.

### Gotcha: `with value of` wants the credential name, not the real key

Wrong:

```text
with value of: sk-or-v1-...
```

This causes an error like:

```text
auth: key "sk-or-v1-..." must be UPPER_SNAKE_CASE
```

Right:

```text
with value of: OPENROUTER_API_KEY
```

Agent Vault then looks up the real value from Credentials.

### Gotcha: the host pattern needs the final `*`

Wrong:

```text
openrouter.ai/api/
```

Right:

```text
openrouter.ai/api/*
```

We discovered this because `agent-vault vault discover --vault prod` showed:

```text
openrouter.ai/api/
```

instead of:

```text
openrouter.ai/api/*
```

The final `*` matters because actual OpenRouter calls go to deeper paths under `/api/`.

---

## Step 10 — Install Agent Vault CLI and Hermes on `hermes-vps`

SSH into `hermes-vps`:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<HERMES_VPS_PUBLIC_IP>
```

Install basics:

```bash
apt-get update -y && apt-get install -y ca-certificates curl tar git tmux jq net-tools iproute2
```

Install Agent Vault CLI:

```bash
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
```

Install Hermes:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup --skip-browser
```

Verify:

```bash
agent-vault version
hermes --version
```

---

## Step 11 — Configure Hermes for OpenRouter placeholders

On `hermes-vps`, write a placeholder-only `.env`:

```bash
mkdir -p /root/.hermes
cat > /root/.hermes/.env <<'EOF'
OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
EOF
chmod 600 /root/.hermes/.env
```

Configure Hermes for OpenRouter:

```bash
hermes config set model.provider openrouter
hermes config set model.default openai/gpt-4o-mini
hermes config set model.base_url https://openrouter.ai/api/v1
```

The important part:

```text
OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
```

That placeholder must match the Agent Vault substitution exactly.

Case matters.

---

## Step 12 — Create the Agent Vault agent identity

In the Agent Vault UI, go to the global Agents page:

```text
http://localhost:14321/agents
```

This is important.

There are two different Agents screens:

1. Vault-level Agents tab
2. Global Agents page

The vault-level screen says:

```text
AI agents with access to this vault
```

That screen only adds an existing agent to the vault.

It does not create a new instance agent.

The global page says something like:

```text
All agents across the instance
```

That is where you create the agent.

Create an agent:

```text
Agent name: hermes-vps
Vault access: prod
Role: proxy
```

If the UI says all instance agents already have access to the vault, you are probably on the wrong Agents screen.

Yes, this is confusing. We hit this exact trap.

---

## Step 13 — Export Agent Vault variables on `hermes-vps`

After creating the agent, Agent Vault shows a connect snippet.

On `hermes-vps`, export:

```bash
export AGENT_VAULT_ADDR=http://10.0.0.2:14321
export AGENT_VAULT_TOKEN=<token from Agent Vault UI>
export AGENT_VAULT_VAULT=prod
```

Do not paste the token into chat.

If the UI gives you:

```text
<AGENT_VAULT_ADDR>
```

replace it with:

```text
http://10.0.0.2:14321
```

Verify:

```bash
printf '%s\n' "$AGENT_VAULT_ADDR" "$AGENT_VAULT_VAULT"
```

Expected:

```text
http://10.0.0.2:14321
prod
```

Verify token exists without printing it:

```bash
test -n "$AGENT_VAULT_TOKEN" && echo TOKEN_SET || echo TOKEN_MISSING
```

Expected:

```text
TOKEN_SET
```

---

## Step 14 — Confirm Agent Vault can see the OpenRouter service

On `hermes-vps`, run:

```bash
agent-vault vault discover --vault prod
```

Expected shape:

```text
Vault: prod

Services
openrouter    openrouter.ai/api/*

Available Credentials
OPENROUTER_API_KEY
```

If it shows:

```text
openrouter.ai/api/
```

instead of:

```text
openrouter.ai/api/*
```

fix the service Host Pattern in the UI.

---

## Step 15 — Start Hermes through Agent Vault

On `hermes-vps`, start Hermes like this:

```bash
agent-vault run -- hermes
```

Do not use plain:

```bash
hermes
```

Plain `hermes` starts Hermes without Agent Vault’s proxy environment.

The wrapper is the whole point.

Inside Hermes, test with a tiny prompt:

```text
say ok
```

If Hermes replies, OpenRouter is working through Agent Vault.

---

## Final working configuration

### Agent Vault service

```text
Name: openrouter
Host Pattern*: openrouter.ai/api/*
Authentication: Passthrough
URL substitution:
  Replace: __OPENROUTER_API_KEY__
  Surface: header only
  with value of: OPENROUTER_API_KEY
```

### Agent Vault credential

```text
Credential name: OPENROUTER_API_KEY
Credential value: real OpenRouter sk-or-v1-... key
```

### Hermes `.env` on `hermes-vps`

```bash
OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
```

### Hermes config

```text
provider: openrouter
base_url: https://openrouter.ai/api/v1
model: openai/gpt-4o-mini
```

### Start command

```bash
agent-vault run -- hermes
```

---

## Optional final hardening — Tailscale + firewall

There are two firewall paths:

### Option A — Public-IP allowlist

Allow SSH only from:

```text
- your M4/laptop's current public IP
- the automation/operator VPS public IP, if Hermes is SSHing from a separate VPS
```

This is fine as a temporary break-glass rule during setup, but I would not use it as the long-term default. Public IPs change, VPNs change them faster, and then you get locked out because the internet enjoys slapstick.

### Option B — Tailscale, recommended

Put these machines in the same Tailscale tailnet:

```text
- your M4/laptop
- av-broker
- hermes-vps
- any separate operator/Hermes host that needs SSH access
```

Then close public SSH after SSH over Tailscale works.

High-level flow:

1. Install Tailscale on `av-broker` and `hermes-vps`.
2. Approve both nodes in the Tailscale admin UI.
3. Verify SSH works to both servers using their Tailscale IPs.
4. Enable `ufw` on both servers.
5. Allow SSH only on `tailscale0`.
6. On `av-broker`, allow Agent Vault ports `14321` and `14322` only from `hermes-vps` private IP `10.0.0.3`.
7. Remove temporary public SSH allowlists once Tailscale access is proven.

Do not rebind Agent Vault to public `0.0.0.0`. Keep it bound to private `10.0.0.2`.

For UI access after public SSH is closed, tunnel over Tailscale:

```bash
ssh -L 14321:10.0.0.2:14321 root@<AV_BROKER_TAILSCALE_IP> -N
```

Then open:

```text
http://localhost:14321
```

If also using Hetzner Cloud Firewall:

```text
Inbound public:
- allow UDP 41641 for Tailscale direct connections, optional but recommended
- optionally keep temporary TCP 22 from your current public IP until Tailscale SSH is proven
- deny all other inbound public traffic

Outbound:
- allow all
```

Agent Vault needs outbound access to OpenRouter and Tailscale needs outbound access for coordination/DERP, so do not get clever and block outbound traffic yet.

---

## Troubleshooting checklist

### SSH asks for password

Use the exact key file:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<SERVER_PUBLIC_IP>
```

If that fails, check local keys:

```bash
find ~/.ssh -maxdepth 1 -type f -name "*.pub" -print -exec ssh-keygen -lf {} \;
```

Hetzner key labels do not prove the local filename.

### `permission denied` when running the key

You accidentally executed the key file.

Wrong:

```bash
~/.ssh/agent_vault_demo_ed25519
```

Right:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes root@<SERVER_PUBLIC_IP>
```

### Agent Vault UI does not open

Make sure the tunnel is still running:

```bash
ssh -i ~/.ssh/agent_vault_demo_ed25519 -o IdentitiesOnly=yes -L 14321:10.0.0.2:14321 root@<AV_BROKER_PUBLIC_IP> -N
```

Then open:

```text
http://localhost:14321
```

### Agent Vault health fails

On `av-broker`, check `tmux`:

```bash
tmux ls
```

Attach:

```bash
tmux attach -t av
```

If needed, restart Agent Vault:

```bash
tmux new-session -d -s av 'AGENT_VAULT_ADDR=http://10.0.0.2:14321 agent-vault server --host 10.0.0.2 --port 14321 --mitm-port 14322'
```

### `agent-vault vault discover` does not show OpenRouter

Check that:

```text
Service name: openrouter
Host Pattern*: openrouter.ai/api/*
Credential: OPENROUTER_API_KEY
```

### Agent token missing

On `hermes-vps`:

```bash
test -n "$AGENT_VAULT_TOKEN" && echo TOKEN_SET || echo TOKEN_MISSING
```

If missing, go back to the global Agents page and rotate/create a token, then export it again.

### Hermes still fails with OpenRouter

Check the common mismatch:

| Place | Must be |
|---|---|
| Agent Vault credential name | `OPENROUTER_API_KEY` |
| Hermes `.env` value | `__OPENROUTER_API_KEY__` |
| Agent Vault substitution placeholder | `__OPENROUTER_API_KEY__` |
| Substitution surface | `header only` |
| Service Host Pattern | `openrouter.ai/api/*` |
| Start command | `agent-vault run -- hermes` |

One character off and the whole thing breaks. Computers remain petty.

---

## What not to expose

Never expose:

```text
real OpenRouter API key
Agent Vault agent token
server passwords
private SSH key contents
```

Safe to expose:

```text
placeholder values
public docs
private IP architecture
Agent Vault UI screens after secrets are hidden
commands with <SERVER_PUBLIC_IP> placeholders
```

---

## One-line summary

Run Agent Vault on `av-broker`, store the real OpenRouter key there, give Hermes only `__OPENROUTER_API_KEY__`, configure Agent Vault to replace that placeholder in headers for `openrouter.ai/api/*`, then start Hermes with `agent-vault run -- hermes`.
