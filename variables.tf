# -------------------------------------------------
# Common Variables 
# -------------------------------------------------

variable "group_name" {
  description = "Akamai Group Name"
  type        = string
}


variable "edgerc_path" {
  type    = string
  default = "~/.edgerc"
}

variable "config_section" {
  type    = string
  default = "default"
}

# -------------------------------------------------
# Edge Hostname
# -------------------------------------------------


variable "edge_hostname_ip_behavior" {
  description = "Akamai Edge Hostname IP behavior"
  type        = string
  default     = "IPV6_COMPLIANCE"
}

# -------------------------------------------------
# CCM Certificate
# -------------------------------------------------

variable "certificate_types" {
  description = "Map of hostname to certificate types to create. Options: ['RSA'], ['ECDSA'], or ['RSA', 'ECDSA']"
  type        = map(list(string))
  default     = {}
  
  validation {
    condition = alltrue([
      for hostname, types in var.certificate_types : alltrue([
        for type in types : contains(["RSA", "ECDSA"], type)
      ])
    ])
    error_message = "Certificate types must be 'RSA' and/or 'ECDSA'."
  }
}

variable "secure_network" {
  description = "Secure network for certificate (ENHANCED_TLS or STANDARD_TLS)"
  type        = string
  default     = "ENHANCED_TLS"
}

variable "certificate_organization" {
  description = "Organization name for certificate subject"
  type        = string
}

variable "certificate_state" {
  description = "State/Province for certificate subject"
  type        = string
}

variable "certificate_locality" {
  description = "City/Locality for certificate subject"
  type        = string
}

variable "certificate_country_code" {
  description = "Two-letter country code for certificate subject"
  type        = string
}

variable "rsa_key_size" {
  description = "RSA key size (2048 or 4096)"
  type        = string
  default     = "2048"
}

variable "ecdsa_key_size" {
  description = "ECDSA key size (256 or 384)"
  type        = string
  default     = "256"
}

variable "enable_acme_signing" {
  description = "Set to true to automatically sign certificates with Let's Encrypt via ACME (requires manual DNS challenge)"
  type        = bool
  default     = false
}

variable "upload_signed_certificates" {
  description = "Set to true to upload signed certificates (after getting CSRs signed externally)"
  type        = bool
  default     = false
}

variable "signed_certificate_rsa_pem" {
  description = "Map of hostname to signed RSA certificate PEM (after external signing)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "signed_certificate_ecdsa_pem" {
  description = "Map of hostname to signed ECDSA certificate PEM (after external signing)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "trust_chain_rsa_pem" {
  description = "Trust chain PEM for RSA certificates"
  type        = string
  default     = ""
  sensitive   = true
}

variable "trust_chain_ecdsa_pem" {
  description = "Trust chain PEM for ECDSA certificates"
  type        = string
  default     = ""
  sensitive   = true
}

variable "certificate_acknowledge_warnings" {
  description = "Acknowledge certificate warnings"
  type        = bool
  default     = false
}

variable "certificate_auto_approve_warnings" {
  description = "Auto-approve certificate warnings"
  type        = list(string)
  default     = [
    "CERTIFICATE_ADDED_TO_TRUST_CHAIN",
    "CERTIFICATE_ALREADY_LOADED",
    "CERTIFICATE_DATA_BLANK_OR_MISSING"
  ]
}

variable "certificate_upload_timeout" {
  description = "Timeout for certificate upload"
  type        = string
  default     = "1h"
}

# -------------------------------------------------
# Property
# -------------------------------------------------

variable "property_name" {
  description = "Akamai Property/Configuration Name"
  type        = string
} 


variable "cp_code_name" {
  description = "Name for the CP Code"
  type        = string
}

variable "origin_hostname" {
  type = string
  description = "Origin hostname"
}

variable "version_notes" {
  type        = string
  description = "Version Notes for the Property"
}


## ----------------------------------------------------------------------------
## Scope
## ----------------------------------------------------------------------------

variable "contract_id" {
  description = "Contract ID for property/config creation"
  type        = string
}


## ----------------------------------------------------------------------------
## Property
## ----------------------------------------------------------------------------

variable "product_id" {
  description = "Property Manager product - Default will be Ion Premier."
  type        = string
  default     = "SPM"
}


variable "hostnames" {
  description = "List of hostnames."
  type        = list(string)
}

variable "rule_format" {
  description = "Property rule format"
  type        = string
  default     = "v2023-10-30"
}


## ----------------------------------------------------------------------------
## Activation
## ----------------------------------------------------------------------------

variable "email" {
  description = "Email address used for activations."
  type        = string
}

variable "activate_to_staging" {
  description = "Set to true to directly activate on the staging network."
  type        = bool
  default     = false
}

variable "activate_to_production" {
  description = "Set to true to directly activate on the production network."
  type        = bool
  default     = false
}

# variable "compliance_record" {
#   description = <<-EOD
#     Set this according to the change management policy if activate_to_production is true. Only for Akamai personnels working in customer accounts

#   EOD
#   type = object({
#     noncompliance_reason = string
#     peer_reviewed_by     = optional(string)
#     customer_email       = optional(string)
#     unit_tested          = optional(bool)
#   })
#   default = null
# }

variable "activation_notes" {
  description = "Activation notes. Leave default value until DXE-2373 is resolved, unless you know what you are doing."
  type        = string
  default     = "activated with terraform"
}

## ----------------------------------------------------------------------------
## CP Code
## ----------------------------------------------------------------------------

variable "cpcode_name" {
  description = "Default CP Code name. Will be the property name (var.name) if null."
  type        = string
  default     = null
}

## ----------------------------------------------------------------------------
## Certificate
## ----------------------------------------------------------------------------

variable "secure_by_default" {
  description = <<-EOD
    Secure by default. Set to true to use the DEFAULT certificate provisioning type.

    This uses edgekey.net and Akamai takes care of provisioning the certificate
    using a Let's Encrypt DV SAN in a fully managed way.

    If the customer requires an OV SAN (CPS_MANAGED), set this to false.
  EOD
  type        = bool
  default     = true
}

## ----------------------------------------------------------------------------
## EdgeHostname
## ----------------------------------------------------------------------------

variable "ip_behavior" {
  description = <<-EOD
    EdgeHostname IP behaviour.
  EOD
  type        = string
  default     = "IPV6_COMPLIANCE"

  validation {
    condition     = length(regexall("^(IPV4|IPV6_COMPLIANCE|IPV6_PERFORMANCE)$", var.ip_behavior)) > 0
    error_message = "ERROR: Valid types are IPV4, IPV6_COMPLIANCE or IPV6_PERFORMANCE."
  }
}

## ----------------------------------------------------------------------------
## Domain Validation
## ----------------------------------------------------------------------------

variable "enable_domain_validation" {
  description = <<-EOD
    Enable domain validation before activation. Required for new domains on Akamai network.
    Set to false to skip domain validation (for existing validated domains).
  EOD
  type        = bool
  default     = true
}

variable "run_domain_validation" {
  description = <<-EOD
    Run the actual domain validation. Set to false on first run to get DCV challenges,
    then add DNS records to your external DNS, then set to true and run again.
    This only applies if enable_domain_validation is true.
  EOD
  type        = bool
  default     = false
}

variable "domain_validation_scope" {
  description = <<-EOD
    Validation scope for domains. Options:
    - HOST: Validates only the exact hostname
    - WILDCARD: Validates one subdomain level (*.example.com)
    - DOMAIN: Validates all hostnames under the domain
  EOD
  type        = string
  default     = "HOST"

  validation {
    condition     = length(regexall("^(HOST|WILDCARD|DOMAIN)$", var.domain_validation_scope)) > 0
    error_message = "ERROR: Valid types are HOST, WILDCARD, or DOMAIN."
  }
}

variable "domain_validation_method" {
  description = <<-EOD
    Domain validation method. Options:
    - DNS_CNAME: Add CNAME record to DNS
    - DNS_TXT: Add TXT record to DNS
    - HTTP: Place file on web server (only for HOST scope)
    Leave empty for automatic validation method selection.
  EOD
  type        = string
  default     = "DNS_CNAME"

  validation {
    condition     = var.domain_validation_method == "" || length(regexall("^(DNS_CNAME|DNS_TXT|HTTP)$", var.domain_validation_method)) > 0
    error_message = "ERROR: Valid types are DNS_CNAME, DNS_TXT, HTTP, or empty string for automatic."
  }
}

variable "enable_edgedns_auto_dcv" {
  description = <<-EOD
    Enable automatic DCV DNS record creation using Akamai EdgeDNS.
    If enabled, DCV validation DNS records will be automatically created in EdgeDNS.
    If disabled, you must manually create DNS records in your external DNS provider.
    Requires EdgeDNS zone to already exist and .edgerc to have EdgeDNS permissions.
  EOD
  type        = bool
  default     = false
}

variable "edgedns_zone" {
  description = "EdgeDNS zone name for automatic DCV record creation (e.g., 'example.com'). Required if enable_edgedns_auto_dcv is true."
  type        = string
  default     = ""
}

variable "edgedns_edgerc_section" {
  description = "EdgeDNS .edgerc section name for DNS API access"
  type        = string
  default     = "default"
}
