---
name: agent-vault-setup
description: Deploy two-host credential-broker patterns where an AI agent runtime reaches public APIs only through a private credential broker/proxy, with HITL handling for secrets.
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [devops, vps, ssh, credential-broker, agent-vault, hermes, telegram, systemd]
---

# Credential Broker VPS Deployments

Use this skill when setting up an agent runtime on one VPS and a credential broker / secret-injection proxy on another VPS, especially for Agent Vault + Hermes Agent demos or production-ish labs.

The point is simple: the agent host should not hold real upstream API keys. It should hold placeholders and a revocable broker token. The broker host holds encrypted credentials and substitutes them at the network boundary.

## Default architecture

- `broker` VPS: credential broker / Agent Vault server.
- `agent` VPS: Hermes or another AI agent runtime.
- Private network between them.
- Broker binds to the private IP only.
- Operator reaches broker UI through SSH tunnel only.
- Agent outbound HTTP/S runs through broker proxy.
- Human enters real credentials only into the broker UI.

For the Agent Vault + Hermes concrete runbook, see `references/agent-vault-hermes-two-vps.md`.

For the OpenRouter adaptation of the Hermes-on-VPS placeholder/substitution flow, see `references/openrouter-placeholder-flow.md`.

For clean reruns where old VPS boxes are deleted and the setup is recreated from zero, see `references/fresh-rebuild-recording-reset.md`.

## Operating rules

1. Verify SSH first, before installing anything.
2. When troubleshooting operator SSH, work one blocker at a time: give one exact command, wait for the output, and do not jump ahead to tunnels/UI/gateway steps until the current SSH failure is fixed.
3. Hetzner SSH key names are labels only. Match by local public-key fingerprint, then use the corresponding private key with `ssh -i <private-key> -o IdentitiesOnly=yes ...`.
4. Verify private IPs and private ping in both directions.
5. Do not bind the broker UI or proxy to `0.0.0.0` during the simple flow.
6. Do not write real API keys into the agent host `.env`.
7. Use placeholders on the agent host, and match them exactly in broker substitution rules.
8. For the Agent Vault Hermes guide pattern, prefer service `Authentication: Passthrough` plus URL substitutions over typed bearer/api-key injection when Hermes emits placeholder credentials on the wire.
9. Keep master password / owner account / API keys / bot tokens as HITL steps.
10. If the broker needs an unlock password, prefer an interactive `tmux` session over storing the master password on disk.
11. Make systemd env inheritance explicit. Services do not inherit the shell that ran setup.
12. Verify the proxy path with network/process evidence, not only with “the bot replied.”
13. Add egress lockdown only after the proxy path is proven. Premature firewall hardening is how you create a very secure brick.
14. For final SSH/admin hardening, prefer Tailscale over long-term public-IP allowlists. Keep public SSH allowlisted only as a temporary break-glass path until SSH over Tailscale is verified.
15. Do not assume cloud firewalls understand Tailscale identity. Use host firewall rules for `tailscale0`; keep broker app traffic on the private network unless you deliberately redesign around tailnet routing.
16. When turning this setup into reusable docs, write for the operator and the agent doing the work. Keep video/creator/viewer framing out of PRDs, runbooks, and checklists unless the explicit deliverable is a production script.

## Safe setup sequence

1. Human provisions VPS boxes and uploads a dedicated SSH public key.
2. Agent verifies SSH and private networking.
3. Agent installs broker binary and starts it bound to private IP.
4. Human completes broker unlock/admin/secrets/services/agent-token setup.
5. Agent installs Hermes/runtime on the agent host.
6. Agent writes placeholder-only `.env` values.
7. Human supplies or pastes the broker agent token only where needed.
8. Agent configures runtime provider/model to route through the broker-compatible upstream.
9. Agent configures gateway/systemd only after broker env variables exist.
10. Agent verifies health, proxy routing, gateway status, logs, and revocation.
11. Only after the broker path works, harden access: install/verify Tailscale on operator + VPS hosts, verify SSH over tailnet, then close public SSH except temporary break-glass allowlists.
12. For clean reruns or recorded walkthroughs, prefer a true clean rebuild: delete the old VPS boxes, generate or archive-and-replace the dedicated SSH key, remove stale `known_hosts` entries, recreate Agent Vault state, and verify from zero rather than pretending dirty hosts are fresh.

## HITL boundaries

Never ask the user to paste these into chat unless they explicitly override the security model:

- Broker master password.
- Broker owner/admin password.
- Anthropic/OpenAI/OpenRouter/GitHub/Slack/Telegram tokens.
- BotFather token.
- Any long-lived cloud provisioning token.

Ask the user to perform those steps in the broker UI or target shell, then report “done”.

## Verification checklist

- SSH works to both public IPs with the dedicated key.
- Private IPs are correct.
- Private ping works both ways.
- Broker binary version prints.
- Broker health endpoint returns success on private IP.
- Broker listeners are on private IP, not public wildcard.
- Agent runtime binary version prints.
- Agent `.env` contains placeholders only.
- `agent-vault run` or equivalent sets proxy env vars.
- Gateway service includes broker env via an explicit environment file or unit drop-in.
- Logs show broker matched service/credential names, not credential values.
- Token rotation/deletion breaks calls; updating token restores them.

## Common pitfalls

- The cloud image may be newer than the upstream guide. Treat docs’ Ubuntu version as an example unless the installer explicitly requires it.
- A copied guide can assume an interactive install wizard. For remote automation, inspect installer flags first and use non-interactive flags where available.
- `agent-vault server` prompts for the master password on first run. Start it in `tmux`, then pause for HITL.
- `HTTPS_PROXY`/`HTTP_PROXY` exported in a shell will not magically apply to a systemd gateway.
- Telegram tokens are usually path substitutions, not header substitutions.
- OpenRouter/OpenAI-style providers can be tempting to configure as typed `bearer`, but the Hermes-on-VPS guide’s placeholder flow wants `Authentication: Passthrough` plus `Surface: header` substitution when Hermes stores `OPENROUTER_API_KEY=__OPENROUTER_API_KEY__` or similar.
- For OpenRouter in that placeholder flow: service name `openrouter`, host `openrouter.ai/api/*`, auth `Passthrough`, substitution placeholder `__OPENROUTER_API_KEY__`, surface `header` only, credential `OPENROUTER_API_KEY`.
- The broker address in a generated UI snippet may be a placeholder; replace it with the private broker URL.
- Do not attach egress-lockdown firewall rules to the broker host. The broker must reach upstream APIs.
