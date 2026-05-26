# Agent Vault + Hermes two-VPS runbook notes

Condensed from the Agent Vault “Hermes on VPS” guide and a live setup session.

## Concrete topology

- `av-broker`: Agent Vault server / credential broker.
- `hermes-vps`: Hermes Agent runtime.
- Private network: `10.0.0.0/24`.
- Example private IPs:
  - broker: `10.0.0.2`
  - Hermes: `10.0.0.3`
- Public IPs are only for SSH. Do not use public IPs for broker traffic.

## Dedicated SSH key pattern

Create a demo-specific key, upload only the `.pub` key to the cloud provider, and use it for both VPS boxes.

Example:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/hermes-vps-agent-vault-demo -C hermes-vps-agent-vault-demo
chmod 600 ~/.ssh/hermes-vps-agent-vault-demo
```

Verify before mutating servers:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o BatchMode=yes root@<broker-public-ip> 'hostname; hostname -I; . /etc/os-release && echo "$PRETTY_NAME"'
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o BatchMode=yes root@<agent-public-ip> 'hostname; hostname -I; . /etc/os-release && echo "$PRETTY_NAME"'
```

Then private networking:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo root@<broker-public-ip> 'ping -c 3 10.0.0.3'
ssh -i ~/.ssh/hermes-vps-agent-vault-demo root@<agent-public-ip> 'ping -c 3 10.0.0.2'
```

## Broker install and start

On `av-broker`:

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl tar tmux jq net-tools iproute2
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
agent-vault version
```

Start in tmux so the human can enter the master password and the process survives SSH disconnects:

```bash
tmux new-session -d -s av 'AGENT_VAULT_ADDR=http://10.0.0.2:14321 agent-vault server --host 10.0.0.2 --port 14321 --mitm-port 14322'
tmux attach -t av
```

HITL: user enters master password and admin setup. Do not ask them to paste those values in chat.

Detach: `Ctrl-b`, then `d`.

Verify:

```bash
curl -sS -I http://10.0.0.2:14321/health
ss -ltnp | grep -E '10\.0\.0\.2:(14321|14322)'
```

Expected: listeners on `10.0.0.2`, not `0.0.0.0`.

## UI tunnel

From operator machine:

```bash
ssh -i ~/.ssh/hermes-vps-agent-vault-demo -L 14321:10.0.0.2:14321 root@<broker-public-ip> -N
```

Open:

```text
http://localhost:14321
```

## Agent Vault UI HITL

Human should create/configure:

- owner/admin account
- vault, usually `prod`
- credentials:
  - `ANTHROPIC_API_KEY`
  - `GITHUB_TOKEN`
  - `SLACK_BOT_TOKEN` if used
  - `TELEGRAM_BOT_TOKEN` after BotFather
- services:

| Name | Host | Placeholder | Surface | Credential |
| --- | --- | --- | --- | --- |
| `anthropic-brain` | `api.anthropic.com` | `__anthropic_api_key__` | `header` | `ANTHROPIC_API_KEY` |
| `github` | `api.github.com` | `__github_token__` | `header` | `GITHUB_TOKEN` |
| `slack` | `slack.com/*` | `__slack_bot_token__` | `header` | `SLACK_BOT_TOKEN` |
| `telegram` | `api.telegram.org` | `__telegram_bot_token__` | `path` | `TELEGRAM_BOT_TOKEN` |

Then create agent `hermes-vps` with `prod:proxy` access and copy the connect snippet.

UI pitfall: `prod` → **Agents** is the vault-level screen for adding an *existing* instance agent, not creating one. To create the agent, use the instance-level route `http://localhost:14321/agents` / left sidebar **Agents** from the home layout, then **Add agent**. If the page says “AI agents with access to this vault,” you are still inside the vault-level tab.

## Hermes host install

On `hermes-vps`:

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl tar git tmux jq net-tools iproute2
curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
agent-vault version
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup --skip-browser
hermes --version
```

`--skip-setup` avoids the interactive Hermes wizard before broker env exists. `--skip-browser` is fine for headless demo if browser tools are not needed; install browser dependencies later if needed.

Write placeholder-only `/root/.hermes/.env`:

```bash
cat > /root/.hermes/.env <<'EOF'
ANTHROPIC_API_KEY=__anthropic_api_key__
GITHUB_TOKEN=__github_token__
SLACK_BOT_TOKEN=__slack_bot_token__
TELEGRAM_BOT_TOKEN=__telegram_bot_token__
EOF
chmod 600 /root/.hermes/.env
```

Configure Hermes to use the upstream that Agent Vault services target. For the Agent Vault guide’s Anthropic service, use Anthropic direct, not OpenRouter:

```bash
hermes config set model.provider anthropic
hermes config set model.default anthropic/claude-opus-4.6
hermes config set model.base_url https://api.anthropic.com
```

## Agent token env

After the UI creates the `hermes-vps` agent, export on `hermes-vps`:

```bash
export AGENT_VAULT_ADDR=http://10.0.0.2:14321
export AGENT_VAULT_TOKEN=<token-from-ui>
export AGENT_VAULT_VAULT=prod
```

Do not put real upstream API keys here. The broker token is still sensitive; prefer entering it in the target shell/UI path rather than chat.

Sanity check:

```bash
agent-vault run -- env | grep -E 'AGENT_VAULT_|HTTPS?_PROXY|SSL_CERT|REQUESTS_CA_BUNDLE'
agent-vault run -- hermes
```

Look for routing through `10.0.0.2:14322`.

## Gateway/systemd gotcha

Shell exports do not apply to systemd. After `agent-vault run -- hermes gateway setup`, add an explicit env file/drop-in before starting the gateway.

Pattern:

```ini
# /etc/systemd/system/hermes-gateway.service.d/override.conf
[Service]
EnvironmentFile=/root/.hermes/gateway.env
```

`/root/.hermes/gateway.env` should contain the Agent Vault address/token/vault and proxy/CA vars as required by the current Agent Vault guide.

## Verification

- `systemctl status hermes-gateway --no-pager`
- `ss -tnp state established | grep -E 'python|14322'`
- Telegram prompt gets a Hermes reply.
- Agent Vault logs show matched service and credential names.
- Rotate/delete the agent token, observe failure, update token, restart gateway, observe recovery.

## Session-specific lessons

- Hetzner’s current Ubuntu LTS may be newer than a guide’s example. Do not warn as if the current LTS is suspicious unless an installer actually fails.
- The Hermes installer supports `--skip-setup`; inspect remote install scripts before assuming they must be manually driven.
- Agent Vault first-run master password is the right HITL stop point. Keep going up to that boundary, then pause.
