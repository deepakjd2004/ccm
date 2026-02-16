
// ACME Configuration for Let's Encrypt certificate signing
// https://registry.terraform.io/providers/vancluever/acme/latest/docs

# Generate a private key for ACME account registration
resource "tls_private_key" "acme_account_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register with ACME server (Let's Encrypt)
resource "acme_registration" "account" {
  account_key_pem = tls_private_key.acme_account_key.private_key_pem
  email_address   = var.email
}

# Sign ECDSA certificates with Let's Encrypt (DNS challenge)
# Note: If both RSA and ECDSA are enabled for the same hostname, they will process sequentially
# Note that when both RSA and ECDSA are enabled, automation will not work 
# because ACME needs to add same source record with different TXT values for RSA and ECDSA challenges, and it seems ACME (edgedns provider) can only 
# add and not update a record. To avoid this, it is recommended not to use hostnames with RSA and ECDSA both or manage this cert validations outside of Terraform.

resource "acme_certificate" "certificate_ecdsa" {
    for_each = var.enable_acme_signing ? toset([
      for hostname in var.hostnames : hostname
      if contains(lookup(var.certificate_types, hostname, []), "ECDSA")
    ]) : toset([])
    
    account_key_pem         = acme_registration.account.account_key_pem
    certificate_request_pem = akamai_cloudcertificates_certificate.ccm_cert_ecdsa[each.key].csr_pem
    
    # DNS challenge using Akamai EdgeDNS
    dns_challenge {
        provider = "edgedns"
        config = {
          AKAMAI_EDGERC = var.edgerc_path
          AKAMAI_EDGERC_SECTION = var.edgedns_edgerc_section
          AKAMAI_PROPAGATION_TIMEOUT = 600 # Increase propagation timeout to 10 minutes to account for DNS delays
        }
    }
}

# Sign RSA certificates with Let's Encrypt (DNS challenge)
# This runs first, before ECDSA certificates. Note that when both RSA and ECDSA are enabled, automation will not work 
# because ACME needs to add same source record with different TXT values for RSA and ECDSA challenges, and it seems ACME (edgedns provider) can only 
# add and not update a record. To avoid this, it is reccomrneded not to use hostnames with RSA and ECDSA both or manage this cert validations outside of Terraform.
resource "acme_certificate" "certificate_rsa" {
    for_each = var.enable_acme_signing ? toset([
      for hostname in var.hostnames : hostname
      if contains(lookup(var.certificate_types, hostname, []), "RSA")
    ]) : toset([])
    
    account_key_pem         = acme_registration.account.account_key_pem
    certificate_request_pem = akamai_cloudcertificates_certificate.ccm_cert_rsa[each.key].csr_pem
    
    # DNS challenge using Akamai EdgeDNS
    dns_challenge {
        provider = "edgedns"
        config = {
          AKAMAI_EDGERC = var.edgerc_path
          AKAMAI_EDGERC_SECTION = var.edgedns_edgerc_section
          AKAMAI_PROPAGATION_TIMEOUT = 600 # Increase propagation timeout to 10 minutes to account for DNS delays
        }
    }
}