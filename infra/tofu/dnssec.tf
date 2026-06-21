resource "cloudflare_zone_settings_override" "agent"{
  zone_id=cloudflare_zone.agent.id;settings{dnssec="on"}}
data "cloudflare_dnssec" "alg8"{zone_id=cloudflare_zone.agent.id}
output "ds_record"{
  value={key_tag=data.cloudflare_dnssec.alg8.key_tag,algorithm=8,
         digest_type=2,digest=data.cloudflare_dnssec.alg8.digest}
  sensitive=true}
