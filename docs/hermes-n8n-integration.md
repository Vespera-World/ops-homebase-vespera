# Hermes ↔ n8n Integration Spec

> Contract between Hermes Agent and n8n for agent-triggered workflows.

## Overview

Hermes agents can trigger n8n workflows via webhooks. n8n executes the workflow and returns a result that Hermes surfaces back to the user.

```
User → Hermes (Telegram/WhatsApp/API) → n8n webhook → workflow runs → response → Hermes → User
```

## Authentication

All webhook calls from Hermes to n8n include:

```http
Authorization: Bearer ${N8N_WEBHOOK_TOKEN}
X-Hermes-Source: telegram | whatsapp | api
X-Hermes-Session: <session_id>
X-Hermes-User: <user_id>
```

The token is stored in:
- Hermes: `N8N_WEBHOOK_TOKEN` env var
- n8n: Webhook node uses "Header Auth" with the same token

## Webhook Endpoints

### 1. Generic Workflow Trigger

```
POST https://n8n.vesperaworld.com/webhook/hermes-workflow
```

**Request:**
```json
{
  "intent": "research_lead",
  "parameters": {
    "company_name": "Acme Corp",
    "domain": "acme.com"
  },
  "context": {
    "session_id": "abc-123",
    "user_id": "8802748002",
    "platform": "telegram",
    "message_id": "42"
  }
}
```

**Response (success):**
```json
{
  "status": "success",
  "data": {
    "summary": "Acme Corp is a $10M ARR SaaS company...",
    "confidence": 0.92,
    "sources": ["linkedin.com", "crunchbase.com"]
  },
  "execution_id": "exec_987654"
}
```

**Response (error):**
```json
{
  "status": "error",
  "error": "Lead not found in CRM",
  "retryable": false
}
```

### 2. Async / Fire-and-Forget

For long-running workflows, Hermes sends the webhook with `?response_mode=async`.

```
POST https://n8n.vesperaworld.com/webhook/hermes-async?response_mode=async
```

**Immediate response:**
```json
{
  "status": "accepted",
  "execution_id": "exec_987654",
  "check_url": "https://n8n.vesperaworld.com/webhook/hermes-status/exec_987654"
}
```

n8n later calls back to Hermes:
```
POST https://hermes.vesperaworld.com/webhooks/n8n-callback
Authorization: Bearer ${HERMES_API_KEY}
```

```json
{
  "execution_id": "exec_987654",
  "status": "completed",
  "result": { ... }
}
```

## Hermes Configuration

Add to `~/.hermes/.env`:

```bash
N8N_ENABLED=true
N8N_WEBHOOK_BASE_URL=https://n8n.vesperaworld.com/webhook
N8N_WEBHOOK_TOKEN=vespera-n8n-webhook-token-2026
N8N_TIMEOUT_MS=30000
N8N_ASYNC_CALLBACK_PATH=/webhooks/n8n-callback
```

## n8n Webhook Node Setup

1. Create a workflow with a "Webhook" trigger node
2. Set Method: `POST`
3. Set Path: `hermes-workflow`
4. Authentication: `Header Auth`
5. Header Name: `Authorization`
6. Header Value: `Bearer vespera-n8n-webhook-token-2026`
7. Add "Respond to Webhook" node at the end of the workflow

## Error Handling

| Scenario | Hermes Behavior |
|----------|-----------------|
| n8n timeout (>30s) | "The workflow is taking too long. I'll check back in a moment." (async fallback) |
| n8n returns 4xx | Log error, tell user the request couldn't be completed |
| n8n returns 5xx | Retry once after 5s, then fail gracefully |
| Network unreachable | Queue for retry, notify admin via Telegram |

## Example: Lead Research Workflow

**Hermes sends:**
```json
{
  "intent": "research_lead",
  "parameters": { "email": "john@acme.com" }
}
```

**n8n does:**
1. Look up contact in Supabase CRM
2. Enrich with Clearbit / Hunter.io
3. Write enrichment back to Supabase
4. Send Slack notification to sales channel
5. Return summary to Hermes

**Hermes replies to user:**
"John at Acme Corp is the CTO. Company is 50 people, Series B. I've updated the CRM."

## Security Checklist

- [ ] Webhook token is >= 32 random characters
- [ ] Token is NOT in Git (use `.env`)
- [ ] n8n webhook uses HTTPS only
- [ ] Hermes callback endpoint validates `Authorization` header
- [ ] Rate limiting on both sides (n8n built-in + Hermes API key)
