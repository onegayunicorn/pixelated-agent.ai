variable "cloudflare_api_token"{type=string;sensitive=true}
variable "domain"{type=string;default="pixelated-agent.ai"}
provider "cloudflare"{api_token=var.cloudflare_api_token}
