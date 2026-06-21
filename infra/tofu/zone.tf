resource "cloudflare_zone" "agent"{zone="pixelated-agent.ai"}
resource "cloudflare_zone" "solutions"{zone="pixelated-solutions.io"}
resource "cloudflare_record" "solutions_cname"{
  zone_id=cloudflare_zone.solutions.id;name="@";type="CNAME"
  value="pixelated-agent.ai";ttl=300;proxied=true}
