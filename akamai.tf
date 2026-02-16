

data "akamai_contract" "contract" {
  group_name = var.group_name
}

resource "akamai_cp_code" "cp_code" {
  product_id  = var.product_id
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  name        = var.cp_code_name
}

module "rules" {
  source = "./rules"
  
  cp_code_id      = akamai_cp_code.cp_code.id
  origin_hostname = var.origin_hostname
}

locals {
  ehn_domain = "edgekey.net"
}


# Domain Validation Resources
# Required to validate domain ownership before activation
resource "akamai_property_domainownership_domains" "domains" {
  count = var.enable_domain_validation ? 1 : 0

  domains = [
    for hostname in var.hostnames : {
      domain_name      = hostname
      validation_scope = var.domain_validation_scope
    }
  ]

  lifecycle {
    ignore_changes = [
      # Challenge data changes frequently, ignore to prevent unnecessary updates
      domains,
    ]
  }
}

# Local helper for domain validation data mapping
locals {
  # Create a map of hostname to domain validation data for easier access
  domain_validation_map = var.enable_domain_validation && length(akamai_property_domainownership_domains.domains) > 0 ? {
    for idx, domain in akamai_property_domainownership_domains.domains[0].domains :
    domain.domain_name => domain
  } : {}
}


# EdgeDNS - Automatic DCV DNS Record Creation (Optional)
# Only creates records if enable_edgedns_auto_dcv is true and validation method is DNS_CNAME or DNS_TXT
resource "akamai_dns_record" "dcv_cname" {
  provider = akamai.edgedns
  
  for_each = var.enable_domain_validation && var.enable_edgedns_auto_dcv && var.domain_validation_method == "DNS_CNAME" ? toset(var.hostnames) : toset([])

  zone       = var.edgedns_zone
  name       = "_acme-challenge.${each.key}"
  recordtype = "CNAME"
  ttl        = 1800
  target     = [
    try(
      local.domain_validation_map[each.key].validation_challenge.cname_record.target,
      "placeholder.akamai.com"  # Placeholder - will be replaced after domain validation resource is created
    )
  ]

  depends_on = [
    akamai_property_domainownership_domains.domains
  ]
  
  lifecycle {
    ignore_changes = [
      target  # Target value comes from domain validation API response
    ]
  }
}

resource "akamai_dns_record" "dcv_txt" {
  provider = akamai.edgedns
  
  for_each = var.enable_domain_validation && var.enable_edgedns_auto_dcv && var.domain_validation_method == "DNS_TXT" ? toset(var.hostnames) : toset([])

  zone       = var.edgedns_zone
  name       = "_akamai-${lower(var.domain_validation_scope)}-challenge.${each.key}"
  recordtype = "TXT"
  ttl        = 3600
  target     = [
    try(
      local.domain_validation_map[each.key].validation_challenge.txt_record.value,
      "placeholder-txt-value"  # Placeholder - will be replaced after domain validation resource is created
    )
  ]

  depends_on = [
    akamai_property_domainownership_domains.domains
  ]
  
  lifecycle {
    ignore_changes = [
      target  # Target value comes from domain validation API response
    ]
  }
}

# Domain Validation - triggers actual validation after DNS/HTTP setup
# Only runs when run_domain_validation is true (after DNS records are added)
resource "akamai_property_domainownership_validation" "validation" {
  count = var.enable_domain_validation && var.run_domain_validation ? 1 : 0

  domains = [
    for hostname in var.hostnames : {
      domain_name       = hostname
      validation_scope  = var.domain_validation_scope
      validation_method = var.domain_validation_method != "" ? var.domain_validation_method : null
    }
  ]

  depends_on = [
    akamai_property_domainownership_domains.domains,
    akamai_dns_record.dcv_cname,
    akamai_dns_record.dcv_txt
  ]
}


# CCM Certificate - RSA (only for hostnames that need RSA)
# Create CSR for each hostname that requires RSA certificate, then upload signed certificate in separate resource
resource "akamai_cloudcertificates_certificate" "ccm_cert_rsa" {
  for_each = toset([
    for hostname in var.hostnames : hostname
    if contains(lookup(var.certificate_types, hostname, []), "RSA")
  ])
  
  contract_id    = data.akamai_contract.contract.id
  group_id       = data.akamai_contract.contract.group_id
  secure_network = var.secure_network
  sans           = var.hostnames
  
  subject =  {
    common_name  = each.value
    organization = var.certificate_organization
    state        = var.certificate_state
    locality     = var.certificate_locality
    country_code = var.certificate_country_code
  }
  
  #certificate_type = "THIRD_PARTY"
  key_type         = "RSA"
  key_size         = tonumber(var.rsa_key_size)
}

# CCM Certificate - ECDSA (only for hostnames that need ECDSA)
# Create CSR for each hostname that requires ECDSA certificate, then upload signed certificate in separate resource
resource "akamai_cloudcertificates_certificate" "ccm_cert_ecdsa" {
  for_each = toset([
    for hostname in var.hostnames : hostname
    if contains(lookup(var.certificate_types, hostname, []), "ECDSA")
  ])
  
  contract_id    = data.akamai_contract.contract.id
  group_id       = data.akamai_contract.contract.group_id
  secure_network = var.secure_network
  sans           = var.hostnames
  
  subject = {
    common_name  = each.value
    organization = var.certificate_organization
    state        = var.certificate_state
    locality     = var.certificate_locality
    country_code = var.certificate_country_code
  }
  
  #certificate_type = "THIRD_PARTY"
  key_type         = "ECDSA"
  key_size         = var.ecdsa_key_size
}

# Upload Signed Certificate - RSA
# Supports both ACME-signed and manually provided certificates
resource "akamai_cloudcertificates_upload_signed_certificate" "ccm_upload_rsa" {
  for_each = (var.upload_signed_certificates || var.enable_acme_signing) ? toset([
    for hostname in var.hostnames : hostname
    if contains(lookup(var.certificate_types, hostname, []), "RSA")
  ]) : toset([])
  
  certificate_id = akamai_cloudcertificates_certificate.ccm_cert_rsa[each.key].certificate_id
  
  # Use ACME-signed certificate if available, otherwise use manually provided
  signed_certificate_pem = var.enable_acme_signing ? acme_certificate.certificate_rsa[each.key].certificate_pem : var.signed_certificate_rsa_pem[each.key]
  
  # Use ACME issuer chain if available, otherwise use manually provided trust chain
  trust_chain_pem = var.enable_acme_signing ? acme_certificate.certificate_rsa[each.key].issuer_pem : var.trust_chain_rsa_pem
  
  acknowledge_warnings = var.certificate_acknowledge_warnings
  
  depends_on = [
    acme_certificate.certificate_rsa
  ]
}

# Upload Signed Certificate - ECDSA
# Supports both ACME-signed and manually provided certificates
resource "akamai_cloudcertificates_upload_signed_certificate" "ccm_upload_ecdsa" {
  for_each = (var.upload_signed_certificates || var.enable_acme_signing) ? toset([
    for hostname in var.hostnames : hostname
    if contains(lookup(var.certificate_types, hostname, []), "ECDSA")
  ]) : toset([])
  
  certificate_id = akamai_cloudcertificates_certificate.ccm_cert_ecdsa[each.key].certificate_id
  
  # Use ACME-signed certificate if available, otherwise use manually provided
  signed_certificate_pem = var.enable_acme_signing ? acme_certificate.certificate_ecdsa[each.key].certificate_pem : var.signed_certificate_ecdsa_pem[each.key]
  
  # Use ACME issuer chain if available, otherwise use manually provided trust chain
  trust_chain_pem = var.enable_acme_signing ? acme_certificate.certificate_ecdsa[each.key].issuer_pem : var.trust_chain_ecdsa_pem
  
  acknowledge_warnings = var.certificate_acknowledge_warnings
  
  depends_on = [
    acme_certificate.certificate_ecdsa
  ]
}


resource "akamai_property" "this" {
  name        = var.property_name
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  product_id  = var.product_id

   dynamic "hostnames" {
    for_each = var.hostnames
    content {
      cname_from             = hostnames.value
      cname_to               = "${hostnames.value}.${local.ehn_domain}"
      cert_provisioning_type = "CCM"
      ccm_certificates  {
        rsa_cert_id   = contains(lookup(var.certificate_types, hostnames.value, []), "RSA") ? akamai_cloudcertificates_certificate.ccm_cert_rsa[hostnames.value].certificate_id : null
        ecdsa_cert_id = contains(lookup(var.certificate_types, hostnames.value, []), "ECDSA") ? akamai_cloudcertificates_certificate.ccm_cert_ecdsa[hostnames.value].certificate_id : null
      }
    }
  }
  rule_format   = module.rules.rule_format
  rules         = module.rules.rules
  version_notes = var.version_notes
  # Version notes depend on values that change on every commit. Ignoring notes as a valid change
  lifecycle {
    ignore_changes = [
      version_notes,
    ]
  }
  depends_on = [
    akamai_property_domainownership_validation.validation,
    akamai_cloudcertificates_certificate.ccm_cert_rsa,
    akamai_cloudcertificates_certificate.ccm_cert_ecdsa,
    akamai_cloudcertificates_upload_signed_certificate.ccm_upload_rsa,
    akamai_cloudcertificates_upload_signed_certificate.ccm_upload_ecdsa
  ]
}

# Data source to retrieve certificate validation challenges for SBD certificates
data "akamai_property_hostnames" "cert_validation" {
  group_id    = data.akamai_contract.contract.group_id
  contract_id = data.akamai_contract.contract.id
  property_id = akamai_property.this.id
  
  depends_on = [
    akamai_property.this
  ]
}

# NOTE: Be careful when removing this resource as you can disable traffic
# Only activates when domain validation is complete (run_domain_validation = true)
resource "akamai_property_activation" "my_property_activation_staging" {
  count = (!var.enable_domain_validation || var.run_domain_validation) ? 1 : 0
  
  property_id                    = akamai_property.this.id
  contact                        = [var.email]
  version                        = var.activate_to_staging ? akamai_property.this.latest_version : akamai_property.this.staging_version
  network                        = "STAGING"
  note                           = var.version_notes
  auto_acknowledge_rule_warnings = true

  # Activation notes depend on values that change on every commit. Ignoring notes as valid change
  lifecycle {
    ignore_changes = [
      note,
    ]
  }
  
  # Depend on validation if it's enabled and running
  depends_on = [
    akamai_property.this,
    akamai_property_domainownership_validation.validation,
    akamai_cloudcertificates_certificate.ccm_cert_rsa,
    akamai_cloudcertificates_certificate.ccm_cert_ecdsa,
    akamai_cloudcertificates_upload_signed_certificate.ccm_upload_rsa,
    akamai_cloudcertificates_upload_signed_certificate.ccm_upload_ecdsa
  ]
}

# NOTE: Be careful when removing this resource as you can disable traffic
resource "akamai_property_activation" "production" {
  count       = var.activate_to_production ? 1 : 0
  network     = "PRODUCTION"
  property_id = akamai_property.this.id
  version     = akamai_property.this.latest_version
  auto_acknowledge_rule_warnings = true
  note        = var.activation_notes
  contact     = [var.email]
  lifecycle {
    ignore_changes = [
      note,
    ]
  }
  depends_on = [
    akamai_property_activation.my_property_activation_staging,
    akamai_cloudcertificates_certificate.ccm_cert_rsa,
    akamai_cloudcertificates_certificate.ccm_cert_ecdsa,
    akamai_cloudcertificates_upload_signed_certificate.ccm_upload_rsa,
    akamai_cloudcertificates_upload_signed_certificate.ccm_upload_ecdsa
  ]
}