# Output domain validation challenge data
# This information is needed to complete DNS or HTTP validation for DCV (Domain Control Validation)
# Add these DNS records to your external DNS provider

# Static DNS records to add - won't change once generated
output "dcv_dns_records_to_add" {
  description = "DNS records to add to your external DNS for DCV validation (static)"
  value = var.enable_domain_validation && length(akamai_property_domainownership_domains.domains) > 0 ? {
    for idx, domain in akamai_property_domainownership_domains.domains[0].domains : 
    domain.domain_name => {
      domain_name      = domain.domain_name
      validation_scope = domain.validation_scope
      
      # DNS CNAME challenge for DCV
      dns_cname = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "cname_record", null) != null ? {
        record_type = "CNAME"
        name        = "_acme-challenge.${domain.domain_name}"
        target      = domain.validation_challenge.cname_record.target
        ttl         = 1800
        note        = "Add this CNAME record to your DNS for DCV validation"
      } : null
      
      # DNS TXT challenge for DCV
      dns_txt = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "txt_record", null) != null ? {
        record_type = "TXT"
        name        = "_akamai-${lower(domain.validation_scope)}-challenge.${domain.domain_name}"
        value       = domain.validation_challenge.txt_record.value
        ttl         = 3600
        note        = "Add this TXT record to your DNS for DCV validation"
      } : null
      
      expires_at = lookup(domain.validation_challenge, "expires_at", null)
    }
  } : null
  
  sensitive = false
}

# Dynamic validation status - will change as Akamai processes validation
output "dcv_validation_status" {
  description = "Current DCV validation status (changes during validation process)"
  value = var.enable_domain_validation && length(akamai_property_domainownership_domains.domains) > 0 ? {
    for idx, domain in akamai_property_domainownership_domains.domains[0].domains : 
    domain.domain_name => {
      status = domain.domain_status
      note   = "Status will change from REQUEST_ACCEPTED → VALIDATION_IN_PROGRESS → VALIDATED"
    }
  } : null
  
  sensitive = false
}

# Full validation details (for troubleshooting)
output "dcv_validation_challenges" {
  description = "Complete DCV validation challenge data including status (for troubleshooting)"
  value = var.enable_domain_validation && length(akamai_property_domainownership_domains.domains) > 0 ? {
    for idx, domain in akamai_property_domainownership_domains.domains[0].domains : 
    domain.domain_name => {
      domain_name      = domain.domain_name
      validation_scope = domain.validation_scope
      status          = domain.domain_status
      
      # DNS CNAME challenge for DCV
      dns_cname = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "cname_record", null) != null ? {
        record_type = "CNAME"
        name        = "_acme-challenge.${domain.domain_name}"
        target      = domain.validation_challenge.cname_record.target
        ttl         = 1800
        note        = "Add this CNAME record to your DNS for DCV validation"
      } : null
      
      # DNS TXT challenge for DCV
      dns_txt = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "txt_record", null) != null ? {
        record_type = "TXT"
        name        = "_akamai-${lower(domain.validation_scope)}-challenge.${domain.domain_name}"
        value       = domain.validation_challenge.txt_record.value
        ttl         = 3600
        note        = "Add this TXT record to your DNS for DCV validation"
      } : null
      
      # HTTP challenge (alternative to DNS)
      http_file = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "http_file", null) != null ? {
        path    = domain.validation_challenge.http_file.path
        content = domain.validation_challenge.http_file.content
        note    = "Place this file on your web server for HTTP validation"
      } : null
      
      http_redirect = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "http_redirect", null) != null ? {
        to = domain.validation_challenge.http_redirect.to
      } : null
      
      expires_at = lookup(domain.validation_challenge, "expires_at", null)
    }
  } : null
  
  sensitive = false
}


output "dns_records_created" {
  description = "Status of automatic DNS record creation"
  value = var.enable_edgedns_auto_dcv ? {
    auto_creation_enabled = true
    zone                  = var.edgedns_zone
    method                = var.domain_validation_method
    note          = "DCV DNS records automatically created in EdgeDNS zone: ${var.edgedns_zone}"
    cname_records = var.domain_validation_method == "DNS_CNAME" ? keys(akamai_dns_record.dcv_cname) : []
    txt_records   = var.domain_validation_method == "DNS_TXT" ? keys(akamai_dns_record.dcv_txt) : []
  } : {
    auto_creation_enabled = false
    zone                  = ""
    method                = ""
    note          = "Automatic DNS record creation is disabled. Use 'dcv_dns_records_to_add' output to get DNS records for manual creation in your external DNS."
    cname_records = []
    txt_records   = []
  }
}


output "property_id" {
  description = "Akamai Property ID"
  value       = akamai_property.this.id
}

output "property_latest_version" {
  description = "Latest property version created"
  value       = akamai_property.this.latest_version
}

output "property_staging_version" {
  description = "Property version activated on staging (0 if not yet activated)"
  value       = akamai_property.this.staging_version
}

output "property_production_version" {
  description = "Property version activated on production (0 if not yet activated)"
  value       = akamai_property.this.production_version
}


output "cp_code_id" {
  description = "CP Code ID"
  value       = akamai_cp_code.cp_code.id
}

# CCM Certificate Outputs
output "ccm_certificate_rsa_info" {
  description = "RSA Certificate IDs and CSRs for external signing - only for hostnames configured with RSA"
  value = length(akamai_cloudcertificates_certificate.ccm_cert_rsa) > 0 ? {
    for hostname, cert in akamai_cloudcertificates_certificate.ccm_cert_rsa : hostname => {
      certificate_id = cert.certificate_id
      csr_pem        = cert.csr_pem
      key_type       = cert.key_type
      key_size       = cert.key_size
      sans           = cert.sans
      common_name    = cert.subject.common_name
      note           = "Take this CSR (csr_pem) to your CA for signing, then upload signed certificate"
    }
  } : null
  sensitive = false
}

output "ccm_certificate_ecdsa_info" {
  description = "ECDSA Certificate IDs and CSRs for external signing - only for hostnames configured with ECDSA"
  value = length(akamai_cloudcertificates_certificate.ccm_cert_ecdsa) > 0 ? {
    for hostname, cert in akamai_cloudcertificates_certificate.ccm_cert_ecdsa : hostname => {
      certificate_id = cert.certificate_id
      csr_pem        = cert.csr_pem
      key_type       = cert.key_type
      key_size       = cert.key_size
      sans           = cert.sans
      common_name    = cert.subject.common_name
      note           = "Take this CSR (csr_pem) to your CA for signing, then upload signed certificate"
    }
  } : null
  sensitive = false
}

output "ccm_certificate_upload_status" {
  description = "Status of signed certificate uploads"
  value = var.upload_signed_certificates ? {
    rsa_certificates = length(akamai_cloudcertificates_certificate.ccm_cert_rsa) > 0 ? {
      for hostname, cert in akamai_cloudcertificates_certificate.ccm_cert_rsa : hostname => {
        certificate_id = cert.certificate_id
        uploaded       = true
        note           = "Signed RSA certificate uploaded successfully"
      }
    } : { note = "No RSA certificates configured" }
    
    ecdsa_certificates = length(akamai_cloudcertificates_certificate.ccm_cert_ecdsa) > 0 ? {
      for hostname, cert in akamai_cloudcertificates_certificate.ccm_cert_ecdsa : hostname => {
        certificate_id = cert.certificate_id
        uploaded       = true
        note           = "Signed ECDSA certificate uploaded successfully"
      }
    } : { note = "No ECDSA certificates configured" }
  } : {
    note = "No signed certificates uploaded yet. Set upload_signed_certificates=true after getting CSRs signed"
  }
}

# ACME Certificate Outputs (Let's Encrypt)
output "acme_certificate_rsa_signed" {
  description = "Let's Encrypt signed RSA certificates (when enable_acme_signing = true)"
  value = var.enable_acme_signing && length(acme_certificate.certificate_rsa) > 0 ? {
    for hostname, cert in acme_certificate.certificate_rsa : hostname => {
      certificate_pem = cert.certificate_pem
      issuer_pem      = cert.issuer_pem
      cert_url        = cert.certificate_url
      note            = "Let's Encrypt signed certificate ready to upload"
    }
  } : null
  sensitive = false
}

output "acme_certificate_ecdsa_signed" {
  description = "Let's Encrypt signed ECDSA certificates (when enable_acme_signing = true)"
  value = var.enable_acme_signing && length(acme_certificate.certificate_ecdsa) > 0 ? {
    for hostname, cert in acme_certificate.certificate_ecdsa : hostname => {
      certificate_pem = cert.certificate_pem
      issuer_pem      = cert.issuer_pem
      cert_url        = cert.certificate_url
      note            = "Let's Encrypt signed certificate ready to upload"
    }
  } : null
  sensitive = false
}


