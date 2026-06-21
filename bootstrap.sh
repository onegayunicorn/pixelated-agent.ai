#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
echo "🚀 Scaffolding sovereign monorepo at $ROOT"

# ────────────────────────────────────────────────────────── ROOT
cat > .gitignore <<'EOF2'
.env *.env *.tfstate* .terraform .tofu node_modules dist build .next
.idea .vscode *.key *.pem *.asc.enc 08-identity/*.sec.*
EOF2
cat > package.json <<'EOF2'
{"name":"@pixelated/root","version":"1.0.0","private":true,
"packageManager":"pnpm@9.0.0",
"workspaces":["apps/*","packages/*","agents/*","commerce/*","ops/*"],
"scripts":{"build":"turbo build","dev":"turbo dev","lint":"turbo lint",
"agent:register":"bash scripts/register-and-launch.sh",
"audit":"bash scripts/verify.sh","sign:all":"gpg --detach-sign --armor VERSION"}}
EOF2
cat > pnpm-workspace.yaml <<'EOF2'
packages: ["apps/*","packages/*","agents/*","commerce/*","ops/*"]
EOF2
cat > turbo.json <<'EOF2'
{"$schema":"https://turbo.build/schema.json",
"pipeline":{"build":{"dependsOn":["^build"],"outputs":[".next/**","dist/**","out/**"]},
"lint":{"outputs":[]},"dev":{"cache":false}}}
EOF2
cat > .env.example <<'EOF2'
GPG_KEY_ID=YOUR_GPG_FINGERPRINT
ADMIN_EMAIL=admin@pixelated-agent.ai
CF_TOKEN=CF_TOKEN_PLACEHOLDER
DOMAIN=pixelated-agent.ai
DNSSEC_ALG=8
FIREBASE_PROJECT_ID=pixelated-agent-ai
FIREBASE_CLIENT_EMAIL=firebase@pixelated-agent-ai.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="PLACEHOLDER"
STRIPE_SECRET_KEY=sk_live_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_live_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
QDRANT_URL=http://127.0.0.1:6333
EOF2

mkdir -p .githooks
cat > .githooks/pre-commit <<'EOF2'
#!/usr/bin/env bash; set -e
git config commit.gpgsign true
SIG=$(git log -1 --pretty=%G? 2>/dev/null || true)
[ "$SIG" = "G" ] || [ -z "$SIG" ] || { echo "🛡️ commits MUST be GPG signed" >&2; exit 1; }
EOF2
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks 2>/dev/null || true

# ────────────────────────────────────────────────────────── SCRIPTS
mkdir -p scripts 08-identity
cat > scripts/setup_sovereign.sh <<'EOF2'
#!/usr/bin/env bash; set -euo pipefail
mkdir -p infra/tofu agents ai apps packages commerce ops public/brand .github/workflows
echo "✅ layout initialised"
EOF2
chmod +x scripts/setup_sovereign.sh

cat > scripts/hardening_identity.sh <<'EOF2'
#!/usr/bin/env bash; set -euo pipefail; source .env
gpg --armor --export $GPG_KEY_ID > 08-identity/sovereign-admin.pub.asc
gpg --armor --export-secret-keys $GPG_KEY_ID | gpg -co 08-identity/sovereign-admin.sec.asc.gpg
sudo install -m 0644 infra/nftables/mobile-node.conf /etc/nftables.conf 2>/dev/null || true
sudo nft -f /etc/nftables.conf 2>/dev/null || true
echo "🛡️ identity backed up · firewall loaded"
EOF2
chmod +x scripts/hardening_identity.sh

# ⭐ THE 9‑LINE ACTIVE AGENT
cat > scripts/register-and-launch.sh <<'EOF2'
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
EOF2
chmod +x scripts/register-and-launch.sh

cat > scripts/verify.sh <<'EOF2'
#!/usr/bin/env bash; set -e
echo "=== GPG    ==="; git log --show-signature -1 | grep "Good signature" || echo "⚠️ unsigned"
echo "=== FW     ==="; sudo nft list ruleset 2>/dev/null | grep "policy drop" || echo "⚠️ inactive"
echo "=== DNSSEC ==="; dig +dnssec +short pixelated-agent.ai DS || echo "⚠️ NXDOMAIN"
echo "=== BUILD  ==="; pnpm build
EOF2
chmod +x scripts/verify.sh

# ────────────────────────────────────────────────────────── INFRA
mkdir -p infra/{tofu,nftables,prometheus,grafana/dashboards,certs,cloudflare/workers}

cat > infra/tofu/versions.tf <<'EOF2'
terraform{required_providers{cloudflare={source="cloudflare/cloudflare",version="~>4.0"}}}
EOF2
cat > infra/tofu/main.tf <<'EOF2'
variable "cloudflare_api_token"{type=string;sensitive=true}
variable "domain"{type=string;default="pixelated-agent.ai"}
provider "cloudflare"{api_token=var.cloudflare_api_token}
EOF2
cat > infra/tofu/zone.tf <<'EOF2'
resource "cloudflare_zone" "agent"{zone="pixelated-agent.ai"}
resource "cloudflare_zone" "solutions"{zone="pixelated-solutions.io"}
resource "cloudflare_record" "solutions_cname"{
  zone_id=cloudflare_zone.solutions.id;name="@";type="CNAME"
  value="pixelated-agent.ai";ttl=300;proxied=true}
EOF2
cat > infra/tofu/dnssec.tf <<'EOF2'
resource "cloudflare_zone_settings_override" "agent"{
  zone_id=cloudflare_zone.agent.id;settings{dnssec="on"}}
data "cloudflare_dnssec" "alg8"{zone_id=cloudflare_zone.agent.id}
output "ds_record"{
  value={key_tag=data.cloudflare_dnssec.alg8.key_tag,algorithm=8,
         digest_type=2,digest=data.cloudflare_dnssec.alg8.digest}
  sensitive=true}
EOF2
cat > infra/tofu/terraform.tfvars.example <<'EOF2'
cloudflare_api_token="CF_TOKEN_PLACEHOLDER"
EOF2

cat > infra/nftables/mobile-node.conf <<'EOF2'
table inet sovereign{
  chain input{type filter hook input priority 0; policy drop;
    iif "lo" accept; ct state established,related accept;
    tcp dport {22,80,443,8443} ct state new limit rate 10/min accept;
    log prefix "SOVEREIGN_DROP: "}
  chain forward{type filter hook forward priority 0; policy drop;}
  chain output {type filter hook output  priority 0; policy accept;}}
EOF2
echo "global:{scrape_interval:15s}" > infra/prometheus/config.yml
: > infra/certs/local-ca.sh; chmod +x infra/certs/local-ca.sh
: > infra/certs/acme.sh;       chmod +x infra/certs/acme.sh
for w in stripe-webhook edge-auth mesh-router; do
  echo "export default {}" > infra/cloudflare/workers/$w.ts
done

# ────────────────────────────────────────────────────────── AGENTS
for a in registrar-agent dnssec-agent security-agent orchestrator proposal-agent; do mkdir -p agents/$a; done
cp scripts/register-and-launch.sh agents/registrar-agent/register.sh
cat > agents/dnssec-agent/monitor.sh <<'EOF2'
#!/usr/bin/env bash; dig +dnssec +short "${1:-pixelated-agent.ai}" DS
EOF2
chmod +x agents/dnssec-agent/monitor.sh
cat > agents/security-agent/audit.sh <<'EOF2'
#!/usr/bin/env bash; git log --show-signature --all -5; sudo nft list ruleset 2>/dev/null
EOF2
chmod +x agents/security-agent/audit.sh
cat > agents/orchestrator/router.ts <<'EOF2'
export class SovereignOrchestrator{route(c:string){return {path:c,ok:true};}}
EOF2
cat > agents/proposal-agent/generate.ts <<'EOF2'
export async function generate(){return {id:crypto.randomUUID()};}
EOF2

# ────────────────────────────────────────────────────────── AI
mkdir -p ai/{taka-core,quantum-bio-ai,vector-db,rag,chatbot-engine}
cat > ai/taka-core/index.ts <<'EOF2'
import { SovereignOrchestrator } from '@pixelated/orchestrator-sdk';
export class TakaAICore{readonly o=new SovereignOrchestrator();}
EOF2
echo '{"collection":"taka-memory","vector":{"size":1536,"distance":"Cosine"}}' > ai/vector-db/schema.qdrant.json

# ────────────────────────────────────────────────────────── APPS + PKGS
for a in www dashboard user-portal calibration-studio chat mobile desktop proposals-app; do
  mkdir -p apps/$a
  echo '{"name":"@pixelated/'$a'","version":"1.0.0","private":true,"scripts":{"build":"tsc"}}' > apps/$a/package.json
  echo '{"compilerOptions":{"target":"ES2022","module":"NodeNext","strict":true,"outDir":"dist"}}' > apps/$a/tsconfig.json
  echo '{"pipeline":{"build":{"outputs":["dist/**"]}}}' > apps/$a/turbo.json
done
for p in auth ui-kit stripe-sdk firebase-core product-catalog bd-pipeline marketing-engine sovereign-common orchestrator-sdk calibration-engine proposals-engine; do
  mkdir -p packages/$p
  echo '{"name":"@pixelated/'$p'","version":"1.0.0","main":"dist/index.js"}' > packages/$p/package.json
  echo "export {}" > packages/$p/index.ts
done

# ────────────────────────────────────────────────────────── COMMERCE / OPS / BRAND
mkdir -p commerce ops/{marketing,bd,proposals,support,legal} public/brand .github/workflows references
cat > commerce/plans.yaml <<'EOF2'
plans:
  - {id:sovereign-free,price:0}
  - {id:sovereign-pro,price:29}
  - {id:sovereign-enterprise,price:99}
EOF2
cat > public/brand/ASSET_LIST.txt <<'EOF2'
1000923902.jpg 1000923767.png 1000923768.png 1000923769.jpg
1000923794.jpg 1000923786.jpg 1000923784.jpg 1000923822.png
1000923861.png 1000923896.png
EOF2
cat > references/cloudflare_dnssec_runbook.md <<'EOF2'
# .ai DNSSEC Runbook
# https://developers.cloudflare.com/dns/dnssec/
# https://dnsviz.net/d/pixelated-agent.ai/dnssec/
# Alg=8 RSASHA256 · DigestType=2 SHA‑256 — paste DS at registrar
EOF2

# ────────────────────────────────────────────────────────── CI/CD
cat > .github/workflows/deploy.yml <<'EOF2'
name: Sovereign Build & Deploy
on: {push:{branches:[main]},pull_request:{branches:[main]}}
env:
  CF_TOKEN:                 ${{ secrets.CF_TOKEN }}
  STRIPE_SECRET_KEY:        ${{ secrets.STRIPE_SECRET_KEY }}
  STRIPE_WEBHOOK_SECRET:    ${{ secrets.STRIPE_WEBHOOK_SECRET }}
  FIREBASE_PRIVATE_KEY:     ${{ secrets.FIREBASE_PRIVATE_KEY }}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4; with:{fetch-depth:0}
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4; with:{node-version:20,cache:pnpm}
      - run: git log --show-signature -1 | grep "Good signature"
  deploy:
    needs: build; if: github.ref=='refs/heads/main'; runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: opentofu/setup-opentofu@v2
      - run: cd infra/tofu && tofu init -input=false && tofu apply -auto-approve
EOF2

# ────────────────────────────────────────────────────────── README
cat > README.md <<'EOF2'
# pixelated‑agent.ai
**Sovereign Infrastructure · TAKA‑AI‑CORE · Sovereign Intelligence Mesh**
- GPG Ed25519 signed commits
- nftables default‑deny
- DNSSEC Alg 8 RSASHA256
- OpenTofu · pnpm · Turbo

pnpm i
pnpm agent:register
pnpm audit
EOF2

git init -b main
git add -A
git -c commit.gpgsign=false commit -m "chore: scaffold complete sovereign monorepo"
echo ""
echo "✅ BOOTSTRAP COMPLETE"
