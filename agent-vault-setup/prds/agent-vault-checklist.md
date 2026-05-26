# Agent Vault + Hermes two-VPS setup — execution checklist

Status: live operator checklist
Source runbook: `prds/agent-vault-steps-agent.md`
Fresh rebuild protocol: `prds/agent-vault-fresh-rebuild.md`
Human guide: `prds/agent-vault-step-by-step.md`
Audience: Hermes agent + human operator

Use this file as the thing Hermes checks off while executing. Do not mark a box complete because a command was attempted. Mark it complete only after the verification/evidence line is satisfied.

---

## How to use this checklist

For each subtask:

```text
[ ] not started
[x] complete and verified
[!] blocked / needs human or fix
```

When a task completes, add a short evidence note under it, for example:

```text
Evidence: ssh returned hostname `av-broker`; no password prompt.
```

Hard rule: if any required verification fails, stop in that phase. Do not jump ahead. That is how setups turn into spaghetti with root access.

---

## Fixed target architecture

- [ ] `av-broker` exists as the Agent Vault broker VPS.
  - Expected private IP: `10.0.0.2`
  - Evidence:

- [ ] `hermes-vps` exists as the Hermes runtime VPS.
  - Expected private IP: `10.0.0.3`
  - Evidence:

- [ ] Agent Vault UI/API target is private only.
  - Expected: `10.0.0.2:14321`
  - Evidence:

- [ ] Agent Vault MITM proxy target is private only.
  - Expected: `10.0.0.2:14322`
  - Evidence:

- [ ] OpenRouter credential will live only in Agent Vault.
  - Credential name: `OPENROUTER_API_KEY`
  - Hermes placeholder: `__OPENROUTER_API_KEY__`
  - Evidence:

- [ ] Hermes will start through Agent Vault.
  - Required command: `agent-vault run -- hermes`
  - Evidence:

---

## Phase 0 — Safety preflight

Goal: make sure the agent knows what it is allowed to automate and where it must stop.

- [ ] Confirm no real secrets will be pasted into chat.
  - Includes: private SSH key, OpenRouter key, Agent Vault master password, admin password, agent token.
  - Evidence:

- [ ] Confirm Agent Vault must not bind to public `0.0.0.0`.
  - Required bind: `10.0.0.2`
  - Evidence:

- [ ] Confirm public IPs are only for SSH bootstrap.
  - Agent Vault UI access must use SSH tunnel.
  - Evidence:

- [ ] Confirm final proof requires more than “Hermes replied.”
  - Required proof: SSH, private networking, broker health, private listeners, service discovery, placeholder env, `agent-vault run` test.
  - Evidence:

- [ ] Confirm firewall hardening comes after the working baseline.
  - Do not firewall yourself into a very expensive paperweight.
  - Evidence:

---

## Phase A — Prepare or verify SSH key

Goal: create/confirm the dedicated SSH key and give the human only the public key.

- [ ] Check whether the private key exists locally.
  - Path: `~/.ssh/hermes-vps-agent-vault-demo`
  - Evidence:

- [ ] If missing, create the key.
  - Command:
    ```bash
    install -d -m 700 ~/.ssh
    ssh-keygen -t ed25519 -f ~/.ssh/hermes-vps-agent-vault-demo -C hermes-vps-agent-vault-demo -N ""
    chmod 600 ~/.ssh/hermes-vps-agent-vault-demo
    chmod 644 ~/.ssh/hermes-vps-agent-vault-demo.pub
    ```
  - Evidence:

- [ ] Print only the public key for upload.
  - Command:
    ```bash
    ssh-keygen -lf ~/.ssh/hermes-vps-agent-vault-demo.pub
    cat ~/.ssh/hermes-vps-agent-vault-demo.pub
    ```
  - Evidence:

- [ ] Verify the private key was not printed or shared.
  - Evidence:

### HITL gate A

- [ ] Human uploaded the `.pub` key to Hetzner/cloud.
  - Human says: `public key uploaded`
  - Evidence:

- [ ] Human created two Ubuntu VPS boxes using that SSH key.
  - Evidence:

- [ ] Human attached both VPS boxes to private network `10.0.0.0/24`.
  - Evidence:

- [ ] Human confirms private IP assignments.
  - `av-broker`: `10.0.0.2`
  - `hermes-vps`: `10.0.0.3`
  - Evidence:

- [ ] Human provided public SSH endpoints only.
  - `AV_BROKER_PUBLIC_IP=<redacted or recorded locally>`
  - `HERMES_VPS_PUBLIC_IP=<redacted or recorded locally>`
  - Evidence:

---

## Phase B — Verify SSH access

Goal: prove both VPS boxes are reachable by SSH before touching packages.

- [ ] Set local operator variables.
  - Command shape:
    ```bash
    SSH_KEY="$HOME/.ssh/hermes-vps-agent-vault-demo"
    AV_BROKER_PUBLIC_IP="<AV_BROKER_PUBLIC_IP>"
    HERMES_VPS_PUBLIC_IP="<HERMES_VPS_PUBLIC_IP>"
    ```
  - Evidence:

- [ ] Verify SSH to `av-broker` with no password prompt.
  - Command:
    ```bash
    ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes root@"$AV_BROKER_PUBLIC_IP" 'hostname; hostname -I; . /etc/os-release && echo "$PRETTY_NAME"'
    ```
  - Expected: exit 0, hostname/IP output, no password prompt.
  - Evidence:

- [ ] Verify SSH to `hermes-vps` with no password prompt.
  - Command:
    ```bash
    ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes root@"$HERMES_VPS_PUBLIC_IP" 'hostname; hostname -I; . /etc/os-release && echo "$PRETTY_NAME"'
    ```
  - Expected: exit 0, hostname/IP output, no password prompt.
  - Evidence:

### Stop conditions B

- [ ] If SSH asks for password, stop and fix SSH key mapping before continuing.
  - Fix: match local `.pub` fingerprint to the key uploaded in Hetzner/cloud.
  - Evidence if triggered:

---

## Phase C — Verify private networking

Goal: prove the broker and Hermes VPS can reach each other over the private network.

- [ ] Ping `hermes-vps` private IP from `av-broker`.
  - Command:
    ```bash
    ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$AV_BROKER_PUBLIC_IP" 'ping -c 3 10.0.0.3'
    ```
  - Expected: `3 packets transmitted, 3 received`
  - Evidence:

- [ ] Ping `av-broker` private IP from `hermes-vps`.
  - Command:
    ```bash
    ssh -i "$SSH_KEY" -o IdentitiesOnly=yes root@"$HERMES_VPS_PUBLIC_IP" 'ping -c 3 10.0.0.2'
    ```
  - Expected: `3 packets transmitted, 3 received`
  - Evidence:

### Stop conditions C

- [ ] If private ping fails, stop and have the human fix the private network attachment/IP assignment.
  - Do not route broker traffic over public IPs.
  - Evidence if triggered:

---

## Phase D — Install Agent Vault on `av-broker`

Goal: install the broker binary and dependencies.

- [ ] Install broker host packages.
  - Packages: `ca-certificates curl tar tmux jq net-tools iproute2`
  - Evidence:

- [ ] Install Agent Vault on `av-broker`.
  - Command shape:
    ```bash
    curl --proto "=https" --proto-redir "=https" --tlsv1.2 -fsSL https://get.agent-vault.dev | AGENT_VAULT_NO_TELEMETRY=1 sh
    ```
  - Evidence:

- [ ] Verify `agent-vault version` prints successfully on `av-broker`.
  - Evidence:

---

## Phase E — Start Agent Vault privately in `tmux`

Goal: start Agent Vault bound to the private broker IP and pause for human first-run setup.

- [ ] Kill stale `tmux` session named `av`, if present.
  - Evidence:

- [ ] Start Agent Vault in `tmux` bound to `10.0.0.2`.
  - Command:
    ```bash
    tmux new-session -d -s av "AGENT_VAULT_ADDR=http://10.0.0.2:14321 agent-vault server --host 10.0.0.2 --port 14321 --mitm-port 14322"
    ```
  - Evidence:

- [ ] Confirm `tmux ls` shows session `av`.
  - Evidence:

### HITL gate E

- [ ] Human attaches to `tmux` on `av-broker`.
  - Command for human:
    ```bash
    ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes root@<AV_BROKER_PUBLIC_IP>
    tmux attach -t av
    ```
  - Evidence:

- [ ] Human enters Agent Vault master password/admin setup directly in `tmux`.
  - Do not paste passwords into chat.
  - Evidence:

- [ ] Human detaches with `Ctrl-b`, then `d`.
  - Evidence:

---

## Phase F — Verify broker health and private binding

Goal: prove Agent Vault is healthy and not publicly bound.

- [ ] Check broker health endpoint.
  - Command:
    ```bash
    curl -fsS http://10.0.0.2:14321/health
    ```
  - Expected:
    ```json
    {"status":"ok"}
    ```
  - Evidence:

- [ ] Check listeners for UI/API and proxy.
  - Command:
    ```bash
    ss -ltnp | grep -E "10\.0\.0\.2:(14321|14322)"
    ```
  - Expected includes:
    ```text
    10.0.0.2:14321
    10.0.0.2:14322
    ```
  - Evidence:

- [ ] Confirm no Agent Vault listener is bound as `0.0.0.0:14321` or `0.0.0.0:14322`.
  - Evidence:

### Stop conditions F

- [ ] If Agent Vault is bound to `0.0.0.0`, stop and restart it bound to `10.0.0.2`.
  - Evidence if triggered:

---

## Phase G — Open Agent Vault UI tunnel

Goal: expose the private Agent Vault UI only to the operator machine.

- [ ] Open SSH tunnel from operator machine.
  - Command:
    ```bash
    ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes -L 14321:10.0.0.2:14321 root@<AV_BROKER_PUBLIC_IP> -N
    ```
  - Evidence:

- [ ] Confirm browser can reach Agent Vault UI.
  - URL: `http://localhost:14321`
  - Evidence:

- [ ] Confirm Agent Vault UI is not exposed publicly.
  - Evidence:

---

## Phase H — Human configures Agent Vault UI

Goal: create vault, credential, service, and agent identity without exposing secrets to chat.

- [ ] Human logs into Agent Vault UI.
  - Evidence:

- [ ] Human creates vault `prod`.
  - Evidence:

- [ ] Human adds real OpenRouter credential.
  - Credential name: `OPENROUTER_API_KEY`
  - Credential value: real OpenRouter key, entered only in UI.
  - Evidence: credential exists; value not seen.

- [ ] Human adds OpenRouter service.
  - Required values:
    ```text
    Name: openrouter
    Host Pattern*: openrouter.ai/api/*
    Authentication: Passthrough
    URL substitution:
      Replace: __OPENROUTER_API_KEY__
      Surface: header only
      with value of: OPENROUTER_API_KEY
    ```
  - Evidence:

- [ ] Human creates Agent Vault agent from the global Agents page.
  - Correct URL: `http://localhost:14321/agents`
  - Agent name: `hermes-vps`
  - Vault access: `prod`
  - Role: `proxy`
  - Evidence:

- [ ] Confirm human did not use the vault-level Agents tab by mistake.
  - Wrong screen text: `AI agents with access to this vault`
  - Evidence:

- [ ] Human copies connect snippet/token but does not paste it into chat.
  - Evidence:

---

## Phase I — Install Agent Vault CLI and Hermes on `hermes-vps`

Goal: prepare the agent runtime host.

- [ ] Install runtime host packages.
  - Packages: `ca-certificates curl tar git tmux jq net-tools iproute2`
  - Evidence:

- [ ] Install Agent Vault CLI on `hermes-vps`.
  - Evidence:

- [ ] Install Hermes on `hermes-vps` with non-interactive flags.
  - Command shape:
    ```bash
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup --skip-browser
    ```
  - Evidence:

- [ ] Verify `agent-vault version` prints on `hermes-vps`.
  - Evidence:

- [ ] Verify `hermes --version` prints on `hermes-vps`.
  - Evidence:

---

## Phase J — Configure Hermes placeholders and OpenRouter provider

Goal: configure Hermes without storing the real OpenRouter key.

- [ ] Create `/root/.hermes` on `hermes-vps`.
  - Evidence:

- [ ] Write placeholder-only `/root/.hermes/.env`.
  - Required exact content:
    ```bash
    OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
    ```
  - Evidence:

- [ ] Lock permissions on `/root/.hermes/.env`.
  - Expected: `600`
  - Evidence:

- [ ] Set Hermes provider to OpenRouter.
  - Command:
    ```bash
    hermes config set model.provider openrouter
    ```
  - Evidence:

- [ ] Set Hermes model.
  - Command:
    ```bash
    hermes config set model.default openai/gpt-4o-mini
    ```
  - Evidence:

- [ ] Set Hermes base URL.
  - Command:
    ```bash
    hermes config set model.base_url https://openrouter.ai/api/v1
    ```
  - Evidence:

- [ ] Verify placeholder exactly matches Agent Vault substitution.
  - Command:
    ```bash
    grep -q "^OPENROUTER_API_KEY=__OPENROUTER_API_KEY__$" /root/.hermes/.env && echo OK
    ```
  - Expected: `OK`
  - Evidence:

- [ ] Verify no real OpenRouter key was written to Hermes config.
  - Command:
    ```bash
    if grep -R "sk-or-v1-" /root/.hermes /root/.config 2>/dev/null; then echo FAIL; else echo OK; fi
    ```
  - Expected: `OK`
  - Evidence:

---

## Phase K — Put Agent Vault runtime token on `hermes-vps`

Goal: place the broker agent token on the runtime host without exposing it in chat.

### HITL gate K

- [ ] Human opens root shell on `hermes-vps`.
  - Command for human:
    ```bash
    ssh -i ~/.ssh/hermes-vps-agent-vault-demo -o IdentitiesOnly=yes root@<HERMES_VPS_PUBLIC_IP>
    ```
  - Evidence:

- [ ] Human writes `/root/.agent-vault-env` directly on `hermes-vps`.
  - Required shape:
    ```bash
    AGENT_VAULT_ADDR=http://10.0.0.2:14321
    AGENT_VAULT_TOKEN=<token from Agent Vault UI>
    AGENT_VAULT_VAULT=prod
    ```
  - Do not paste token into chat.
  - Evidence:

- [ ] Human sets `/root/.agent-vault-env` permissions to `600`.
  - Evidence:

- [ ] Human says only `done` after token file exists.
  - Evidence:

### Agent verification K

- [ ] Verify Agent Vault env file exists without printing token.
  - Evidence:

- [ ] Verify `AGENT_VAULT_ADDR` equals `http://10.0.0.2:14321`.
  - Evidence:

- [ ] Verify `AGENT_VAULT_VAULT` equals `prod`.
  - Evidence:

- [ ] Verify `AGENT_VAULT_TOKEN` is non-empty without printing it.
  - Expected: `AGENT_VAULT_ENV_OK`
  - Evidence:

---

## Phase L — Discover vault contents from `hermes-vps`

Goal: prove the runtime host can see the right broker service and credential metadata.

- [ ] Run vault discovery from `hermes-vps`.
  - Command:
    ```bash
    . /root/.agent-vault-env
    agent-vault vault discover --vault prod
    ```
  - Evidence:

- [ ] Confirm discovery shows vault `prod`.
  - Evidence:

- [ ] Confirm discovery shows service `openrouter`.
  - Evidence:

- [ ] Confirm discovery shows host pattern `openrouter.ai/api/*` with final `*`.
  - Evidence:

- [ ] Confirm discovery shows available credential `OPENROUTER_API_KEY`.
  - Evidence:

### Stop conditions L

- [ ] If host pattern appears as `openrouter.ai/api/` without `*`, stop and fix the UI service.
  - Evidence if triggered:

- [ ] If credential is missing, stop and fix Agent Vault Credentials.
  - Evidence if triggered:

---

## Phase M — Final non-interactive Hermes test through Agent Vault

Goal: prove Hermes can make a model call through Agent Vault.

- [ ] Run one-shot Hermes command through Agent Vault.
  - Command:
    ```bash
    . /root/.agent-vault-env
    agent-vault run -- hermes chat -Q -q "Reply with exactly: ok"
    ```
  - Expected: `ok`
  - Evidence:

- [ ] Confirm command used `agent-vault run --`, not plain `hermes`.
  - Evidence:

- [ ] If the model call fails, check mismatch table before changing models.
  - Mismatch table:
    ```text
    Agent Vault credential name: OPENROUTER_API_KEY
    Hermes .env value: __OPENROUTER_API_KEY__
    Agent Vault substitution placeholder: __OPENROUTER_API_KEY__
    Substitution surface: header only
    Service Host Pattern: openrouter.ai/api/*
    Start command: agent-vault run -- hermes
    ```
  - Evidence if triggered:

---

## Phase N — Optional interactive session start

Goal: start an interactive Hermes session only after the deterministic one-shot test works.

- [ ] Open root shell on `hermes-vps`.
  - Evidence:

- [ ] Source `/root/.agent-vault-env`.
  - Evidence:

- [ ] Start interactive Hermes through Agent Vault.
  - Command:
    ```bash
    agent-vault run -- hermes
    ```
  - Evidence:

- [ ] Test inside Hermes with `say ok`.
  - Expected: Hermes replies.
  - Evidence:

---

## Phase O — Tailscale + firewall hardening

Goal: close public access after the working baseline is proven.

Default: use Tailscale. Use public-IP allowlisting only as temporary break-glass.

### O1 — Install and authenticate Tailscale

- [ ] Confirm baseline setup is already working before firewalling.
  - Required: Phase M complete.
  - Evidence:

- [ ] Confirm operator M4/laptop is in the Tailscale tailnet.
  - Evidence:

- [ ] Install Tailscale on `av-broker`.
  - Command shape:
    ```bash
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --hostname=av-broker --ssh --accept-dns=false
    ```
  - Evidence:

- [ ] Human approves `av-broker` auth URL in Tailscale admin UI if prompted.
  - Do not paste auth keys into chat.
  - Evidence:

- [ ] Install Tailscale on `hermes-vps`.
  - Command shape:
    ```bash
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up --hostname=hermes-vps --ssh --accept-dns=false
    ```
  - Evidence:

- [ ] Human approves `hermes-vps` auth URL in Tailscale admin UI if prompted.
  - Do not paste auth keys into chat.
  - Evidence:

- [ ] Record `av-broker` Tailscale IP locally.
  - Do not publish if user wants IPs redacted.
  - Evidence:

- [ ] Record `hermes-vps` Tailscale IP locally.
  - Do not publish if user wants IPs redacted.
  - Evidence:

### O2 — Verify SSH over Tailscale before closing public SSH

- [ ] SSH to `av-broker` over Tailscale works.
  - Command:
    ```bash
    ssh root@<AV_BROKER_TAILSCALE_IP> 'hostname; tailscale ip -4'
    ```
  - Evidence:

- [ ] SSH to `hermes-vps` over Tailscale works.
  - Command:
    ```bash
    ssh root@<HERMES_VPS_TAILSCALE_IP> 'hostname; tailscale ip -4'
    ```
  - Evidence:

- [ ] Confirm public SSH is still available as break-glass until both Tailscale SSH checks pass.
  - Evidence:

### O3 — Apply host firewall rules

- [ ] On `av-broker`, install and reset `ufw`.
  - Evidence:

- [ ] On `av-broker`, default deny incoming and allow outgoing.
  - Evidence:

- [ ] On `av-broker`, allow SSH only on `tailscale0`.
  - Rule:
    ```bash
    ufw allow in on tailscale0 to any port 22 proto tcp
    ```
  - Evidence:

- [ ] On `av-broker`, allow Agent Vault UI/API only from `hermes-vps` private IP.
  - Rule:
    ```bash
    ufw allow from 10.0.0.3 to any port 14321 proto tcp
    ```
  - Evidence:

- [ ] On `av-broker`, allow Agent Vault proxy only from `hermes-vps` private IP.
  - Rule:
    ```bash
    ufw allow from 10.0.0.3 to any port 14322 proto tcp
    ```
  - Evidence:

- [ ] On `av-broker`, enable `ufw` and capture `ufw status verbose`.
  - Evidence:

- [ ] On `hermes-vps`, install and reset `ufw`.
  - Evidence:

- [ ] On `hermes-vps`, default deny incoming and allow outgoing.
  - Evidence:

- [ ] On `hermes-vps`, allow SSH only on `tailscale0`.
  - Rule:
    ```bash
    ufw allow in on tailscale0 to any port 22 proto tcp
    ```
  - Evidence:

- [ ] On `hermes-vps`, enable `ufw` and capture `ufw status verbose`.
  - Evidence:

### O4 — Verify after firewall

- [ ] SSH to `av-broker` over Tailscale still works after `ufw`.
  - Evidence:

- [ ] SSH to `hermes-vps` over Tailscale still works after `ufw`.
  - Evidence:

- [ ] `hermes-vps` can still reach Agent Vault health on private IP.
  - Command from `hermes-vps`:
    ```bash
    curl -fsS http://10.0.0.2:14321/health
    ```
  - Expected: `{"status":"ok"}`
  - Evidence:

- [ ] Final one-shot Hermes test still works after firewall.
  - Command:
    ```bash
    . /root/.agent-vault-env
    agent-vault run -- hermes chat -Q -q "Reply with exactly: ok"
    ```
  - Expected: `ok`
  - Evidence:

- [ ] Agent Vault UI tunnel works over Tailscale.
  - Command:
    ```bash
    ssh -L 14321:10.0.0.2:14321 root@<AV_BROKER_TAILSCALE_IP> -N
    ```
  - URL: `http://localhost:14321`
  - Evidence:

### O5 — Hetzner/cloud firewall cleanup

- [ ] If using Hetzner Cloud Firewall, allow UDP `41641` inbound for Tailscale direct connections.
  - Evidence:

- [ ] Temporarily keep TCP `22` from the operator’s current public IP only until Tailscale SSH is proven.
  - Evidence:

- [ ] After Tailscale SSH is proven, remove temporary public TCP `22` allowlist.
  - Evidence:

- [ ] Deny all other public inbound traffic.
  - Evidence:

- [ ] Keep outbound allowed.
  - Reason: Agent Vault must reach OpenRouter; Tailscale needs coordination/DERP.
  - Evidence:

---

## Phase P — Optional revocation proof

Goal: prove the broker token can be revoked and restored.

Only do this if the material requires revocation proof.

- [ ] Human rotates or deletes the `hermes-vps` agent token in Agent Vault UI.
  - Do not paste token into chat.
  - Evidence:

- [ ] Re-run one-shot Hermes command and confirm it fails.
  - Evidence:

- [ ] Human writes the new token into `/root/.agent-vault-env` directly on `hermes-vps`.
  - Evidence:

- [ ] Re-run one-shot Hermes command and confirm it returns `ok`.
  - Evidence:

---

## Final acceptance checklist

The setup is done only when all required boxes below are checked.

- [ ] SSH verified to both public IPs during bootstrap.
  - Evidence:

- [ ] Private network verified both ways.
  - Evidence:

- [ ] Agent Vault installed on `av-broker`.
  - Evidence:

- [ ] Agent Vault is healthy on `10.0.0.2:14321`.
  - Evidence:

- [ ] Agent Vault listeners are private on `10.0.0.2:14321` and `10.0.0.2:14322`.
  - Evidence:

- [ ] Agent Vault vault `prod` exists.
  - Evidence:

- [ ] Agent Vault credential `OPENROUTER_API_KEY` exists; value was not seen by Hermes.
  - Evidence:

- [ ] Agent Vault service `openrouter` uses `openrouter.ai/api/*`.
  - Evidence:

- [ ] Agent Vault service uses `Authentication: Passthrough`.
  - Evidence:

- [ ] Agent Vault substitution replaces `__OPENROUTER_API_KEY__` on header surface only with credential `OPENROUTER_API_KEY`.
  - Evidence:

- [ ] Agent Vault global agent `hermes-vps` exists with access to `prod` as proxy.
  - Evidence:

- [ ] Hermes installed on `hermes-vps`.
  - Evidence:

- [ ] Hermes `.env` contains placeholder only.
  - Evidence:

- [ ] Hermes config points to OpenRouter base URL `https://openrouter.ai/api/v1`.
  - Evidence:

- [ ] `/root/.agent-vault-env` exists and token is non-empty, without printing the token.
  - Evidence:

- [ ] `agent-vault vault discover --vault prod` shows the correct service and credential.
  - Evidence:

- [ ] `agent-vault run -- hermes chat -Q -q "Reply with exactly: ok"` returns `ok`.
  - Evidence:

- [ ] Secret leak check passes on `hermes-vps`.
  - Expected: no `sk-or-v1-` under `/root/.hermes` or `/root/.config`.
  - Evidence:

- [ ] If firewall hardening was requested, Tailscale SSH works and public inbound is closed.
  - Evidence:

- [ ] Final report delivered to user with secrets redacted.
  - Evidence:

---

## Final report template

```text
Agent Vault + Hermes VPS setup report

Inputs used:
- broker public host: <redacted or shown if user permits>
- Hermes public host: <redacted or shown if user permits>
- SSH key path: ~/.ssh/hermes-vps-agent-vault-demo
- broker private IP: 10.0.0.2
- Hermes private IP: 10.0.0.3

Phase status:
- Phase A SSH key: done/blocked/skipped
- Phase B SSH access: done/blocked/skipped
- Phase C private network: done/blocked/skipped
- Phase D broker install: done/blocked/skipped
- Phase E broker tmux start: done/blocked/skipped
- Phase F broker health/private binding: done/blocked/skipped
- Phase G UI tunnel: done/blocked/skipped
- Phase H UI config/HITL: done/blocked/skipped
- Phase I runtime install: done/blocked/skipped
- Phase J Hermes placeholder config: done/blocked/skipped
- Phase K Agent Vault token env: done/blocked/skipped
- Phase L vault discovery: done/blocked/skipped
- Phase M final one-shot test: done/blocked/skipped
- Phase N interactive session: done/blocked/skipped
- Phase O Tailscale/firewall: done/blocked/skipped
- Phase P revocation proof: done/blocked/skipped

Verified:
- SSH: yes/no
- private networking: yes/no
- Agent Vault private listeners: yes/no
- OpenRouter service pattern: yes/no
- Hermes placeholder-only env: yes/no
- Agent Vault token present but not printed: yes/no
- final `agent-vault run -- hermes` test: yes/no
- firewall/Tailscale hardening: yes/no/not requested

Secrets handling:
- private SSH key not pasted into chat: yes/no
- OpenRouter key not pasted into chat: yes/no
- Agent Vault passwords not pasted into chat: yes/no
- Agent Vault token not printed: yes/no
- real OpenRouter key not found on Hermes host: yes/no

Remaining risks / next choices:
- production hardening beyond baseline: yes/no needed
- systemd/gateway persistence: yes/no needed
- revocation proof: yes/no completed
```
