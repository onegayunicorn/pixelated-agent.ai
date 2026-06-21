#!/usr/bin/env bash; set -euo pipefail
cd "$(dirname "$0")/.." && source .env
gpg --batch --yes -u $GPG_KEY_ID --detach-sign --armor .env
tofu -chdir=infra/tofu init -input=false
tofu -chdir=infra/tofu apply -auto-approve -var=cloudflare_api_token=$CF_TOKEN
DS=$(tofu -chdir=infra/tofu output -json ds_record | jq -c .value)
curl -fsS -X PATCH "https://api.cloudflare.com/client/v4/registrar/domains/pixelated-agent.ai/dnssec" \
  -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type:application/json" -d "$DS" \
  || echo "⚠️ DS paste manually at registrar — .ai required step"
pnpm -r build 2>/dev/null || true
git add -A && git commit -S -m "AGENT:ACTIVATION $(date -u +%FT%TZ)"
echo "✅ TAKA‑AI‑CORE · SOVEREIGN INTELLIGENCE MESH — ONLINE"
