terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 9.3.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "akamai" {
  edgerc         = var.edgerc_path
  config_section = var.config_section
}

# Separate provider for EdgeDNS operations (if different section needed)
provider "akamai" {
  alias          = "edgedns"
  edgerc         = var.edgerc_path
  config_section = var.edgedns_edgerc_section
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}