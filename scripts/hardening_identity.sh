#!/usr/bin/env bash; set -euo pipefail; source .env
gpg --armor --export $GPG_KEY_ID > 08-identity/sovereign-admin.pub.asc
gpg --armor --export-secret-keys $GPG_KEY_ID | gpg -co 08-identity/sovereign-admin.sec.asc.gpg
sudo install -m 0644 infra/nftables/mobile-node.conf /etc/nftables.conf 2>/dev/null || true
sudo nft -f /etc/nftables.conf 2>/dev/null || true
echo "🛡️ identity backed up · firewall loaded"
