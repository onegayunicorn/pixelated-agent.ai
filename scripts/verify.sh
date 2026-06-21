#!/usr/bin/env bash; set -e
echo "=== GPG    ==="; git log --show-signature -1 | grep "Good signature" || echo "⚠️ unsigned"
echo "=== FW     ==="; sudo nft list ruleset 2>/dev/null | grep "policy drop" || echo "⚠️ inactive"
echo "=== DNSSEC ==="; dig +dnssec +short pixelated-agent.ai DS || echo "⚠️ NXDOMAIN"
echo "=== BUILD  ==="; pnpm build
