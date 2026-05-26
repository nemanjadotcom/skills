# Agent Vault Hermes-on-VPS OpenRouter placeholder flow

Session lesson: when adapting the Agent Vault Hermes-on-VPS guide from Anthropic to OpenRouter, preserve the guide's credential-substitution model instead of switching to typed bearer injection.

Use this service config in the Agent Vault UI when Hermes has a placeholder value like:

```env
OPENROUTER_API_KEY=__OPENROUTER_API_KEY__
```

Service:

```text
Name: openrouter
Host: openrouter.ai/api/*
Authentication: Passthrough
```

URL Substitution:

```text
Placeholder: __OPENROUTER_API_KEY__
Surface: header only
Credential: OPENROUTER_API_KEY
```

Reason: Hermes/OpenRouter places the API key value in an outbound request header. In this flow the value is the placeholder, and Agent Vault scans headers and swaps the placeholder for the real credential at the broker boundary. Typed `bearer` can also be valid Agent Vault generally, but it is not the UI path described by the Hermes-on-VPS guide and can confuse a non-developer walkthrough.

Operator UX rule from the same session: during live SSH/tunnel repair, give one exact command at a time and wait for the result. Do not stack future steps while the current blocker is unresolved.
