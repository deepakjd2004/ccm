# Akamai Property with CCM Third-Party Certificates

This Terraform configuration manages Akamai properties with CCM (Cloud Certificate Manager) third-party certificates. Supports flexible certificate type selection (RSA, ECDSA, or both) per hostname with automatic Let's Encrypt signing via ACME. Most probably akamai customers would not be using Let's Encrypt certs with CCM and it is for internal(Akamai) testing only. Akamai customer should replace Let's Encrypt terraform provider and build similar logic with their choice of CA(if they provide terraform module for requesting and downloading certificates)

## Prerequisites

Before using this Terraform configuration, you need:

1. **Akamai Account & Credentials**
   - Active Akamai account with CCM (Cloud Certificate Manager) enabled
   - API credentials configured in `~/.edgerc` file
   - Appropriate permissions for Property Manager, Certificate Provisioning System, and EdgeDNS

2. **Terraform**
   - Terraform version >= 1.0
   - Akamai Terraform Provider >= 9.3.0

3. **Setup Instructions**
   - Copy `terraform.auto.tfvars.example` to `terraform.auto.tfvars`
   - Update the values in `terraform.auto.tfvars` with your specific configuration
   - Make changes to rules/template\*.tf as per your need. For e.g. you need to update Sureroute Map, SS Map, custom map etc
   - **IMPORTANT**: Never commit `terraform.auto.tfvars` or `.edgerc` files to version control

4. **EdgeRC Configuration**
   - Create `~/.edgerc` file with your Akamai API credentials:
     `     [default]
client_secret = your_client_secret
host = akaa-xxxxxxxxx.luna.akamaiapis.net
access_token = your_access_token
client_token = your_client_token`

You can also store Akamai credentials in KMS or as cicd pipeline secrets

## Architecture

- **Flexible Certificate Types**: Choose RSA, ECDSA, or both per hostname via `certificate_types` map in `terraform.auto.tfvars`
- **CCM Certificates**: Creates third-party certificates with customer-managed keys
- **Certificate Workflow Options**:
  - **Option 1(Internal Testing only, akaami customer would not use it as SBD would be better approach for using Let's encrypt certificates)**: Automatic signing with Let's Encrypt/ACME + EdgeDNS(customers can replace this with their DNS provider)
  - **Option 2**: Manual CSR generation → External CA signing → Upload
- **Domain Validation**: DCV (Domain Control Validation) for new domains
- **Edge Hostnames**: Automatically created by Akamai when property is activated as part of hostname block in akamai_property resource with `cert_provisioning_type` selected as `CCM`

## Quick Start: Automatic Let's Encrypt Certificates for testing by internal Akamai users

### Single-Phase Deployment (Recommended for internal testing)

1. **Configure variables in `terraform.auto.tfvars`**:

   ```hcl
   hostnames = ["www.example.com"]

   # Choose certificate types per hostname
   certificate_types = {
     "ccm-www.example.com" = ["RSA"]  # or you can mention both RSA and ECDSA but with ACME it will not work as ACME uses DCV TXT record name by appending hostname and it will be same for both RSA and ECDSA cert. For e.g. _acme-challenge.ccm-www.example.com for both ECDSA and RSA but value of TXT record changes.  ACME edgedns subprovider can only add and not update the record so second cert validation will never complete.
     # OR just one:
     # "example.com" = ["RSA"]      # Only RSA
     # "example2.com" = ["ECDSA"]   # Only ECDSA
   }

   # Enable ACME/Let's Encrypt automatic signing
   enable_acme_signing = true

   # Certificate subject information
   certificate_organization = "Customer Org"
   certificate_state        = "MA"
   certificate_locality     = "Cambridge"
   certificate_country_code = "US"

   # Domain validation (needed for new domains)
   run_domain_validation = true
   edgedns_zone              = "example.com"
   domain_validation_method  = "DNS_TXT" # Options: DNS_CNAME, DNS_TXT, HTTP (empty for auto), Keep this to DNS_TXT to avoid conflict with acme validation
   ```

2. **Run Terraform**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **What happens automatically**:
   - Creates CCM certificates and generates CSRs
   - ACME provider requests certificates from Let's Encrypt
   - EdgeDNS automatically creates DNS CNAME records for cert validation (`_acme-challenge.yourdomain.com`)
   - Let's Encrypt validates and signs certificates
   - Signed certificates automatically uploaded to Akamai CCM
   - Domain validation completed using TXT record
   - Property created/updated with certificates
   - Activation to staging (if enabled)

## Alternative: Manual Certificate Workflow

### Phase 1: Generate CSRs (Initial Apply)

For customers as they will alomost always use 3rd party CA instead of Let's Encrypt:

1. **Configure variables in `terraform.auto.tfvars`**:

   ```hcl
   hostnames = ["ccm-www.example.com", "www.ccm-www.example.com"]

   # Choose certificate types per hostname
   certificate_types = {
     "ccm-www.example.com"     = ["RSA", "ECDSA"]
     "www.ccm-www.example.com" = ["RSA"]  # Only RSA for www
   }

   # Disable ACME, keep manual upload disabled initially
   enable_acme_signing        = false
   upload_signed_certificates = false
   run_domain_validation      = false

   # Certificate subject information, all are optional
   certificate_organization = "Customer Org"
   certificate_state        = "MA"
   certificate_locality     = "Cambridge"
   certificate_country_code = "US"
   ```

2. **Run Terraform**:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Retrieve CSRs from outputs**:

   ```bash
   # Get RSA CSRs
   terraform output -json ccm_certificate_rsa_info

   # Get ECDSA CSRs
   terraform output -json ccm_certificate_ecdsa_info
   ```

4. **Submit CSRs to your CA**:
   - For each hostname, you'll get CSRs based on your `certificate_types` configuration
   - Send each CSR to your Certificate Authority for signing
   - Wait for signed certificates and trust chains

### Phase 2: Upload Signed Certificates

1. **Update `terraform.auto.tfvars` with signed certificates**:

   ```hcl
   upload_signed_certificates = true

   signed_certificate_rsa_pem = {
     "ccm-www.example.com" = <<-EOT
       -----BEGIN CERTIFICATE-----
       <your signed RSA certificate for ccm-demo1>
       -----END CERTIFICATE-----
     EOT
     "www.ccm-www.example.com" = <<-EOT
       -----BEGIN CERTIFICATE-----
       <your signed RSA certificate for www>
       -----END CERTIFICATE-----
     EOT
   }

   signed_certificate_ecdsa_pem = {
     "ccm-www.example.com" = <<-EOT
       -----BEGIN CERTIFICATE-----
       <your signed ECDSA certificate for ccm-demo1>
       -----END CERTIFICATE-----
     EOT
     "www.ccm-www.example.com" = <<-EOT
       -----BEGIN CERTIFICATE-----
       <your signed ECDSA certificate for www>
       -----END CERTIFICATE-----
     EOT
   }

   trust_chain_rsa_pem = <<-EOT
     -----BEGIN CERTIFICATE-----
     <intermediate CA certificate>
     -----END CERTIFICATE-----
     -----BEGIN CERTIFICATE-----
     <root CA certificate>
     -----END CERTIFICATE-----
   EOT

   trust_chain_ecdsa_pem = <<-EOT
     -----BEGIN CERTIFICATE-----
     <intermediate CA certificate>
     -----END CERTIFICATE-----
     -----BEGIN CERTIFICATE-----
     <root CA certificate>
     -----END CERTIFICATE-----
   EOT
   ```

2. **Apply to upload certificates and create property**:

   ```bash
   terraform plan
   terraform apply
   ```

   This will:
   - Upload signed certificates to Akamai
   - Create the Akamai property with CCM certificates attached
   - Skip activation (domain validation not run yet)

### Phase 3: Domain Validation & Activation (Optional for New Domains)

If your domains are new to Akamai and require DCV:

#### Option A: Automatic DCV with EdgeDNS (Recommended if using EdgeDNS)

1. **Enable EdgeDNS automatic DCV in `terraform.auto.tfvars`**:

   ```hcl
   enable_edgedns_auto_dcv   = true
   edgedns_zone              = "example.com"  # Your EdgeDNS zone
   run_domain_validation     = true
   activate_to_staging       = true
   ```

2. **Apply to create DCV DNS records and validate automatically**:

   ```bash
   terraform apply
   ```

   This will:
   - Automatically create DCV DNS records in your EdgeDNS zone
   - Run domain validation
   - Activate property to staging

#### Option B: Manual DCV with External DNS

1. **Check DCV challenges**:

   ```bash
   terraform output -json dcv_dns_records_to_add
   ```

2. **Add DNS records to your external DNS provider**:
   - Add the CNAME or TXT records shown in the output
   - Wait for DNS propagation (check with `dig` or `nslookup`)

3. **Enable validation in `terraform.auto.tfvars`**:

   ```hcl
   run_domain_validation = true
   activate_to_staging   = true
   ```

   ```hcl
   run_domain_validation = true
   activate_to_staging   = true
   ```

4. **Apply to validate and activate**:
   ```bash
   terraform apply
   ```

## Resource Creation Flow

```
┌─────────────────────────────────────┐
│  akamai_cloudcertificates_certificate │ (RSA/ECDSA based on certificate_types)
│  - Generates CSR                     │
│  - Returns certificate_id            │
└─────────────┬───────────────────────┘
              │ certificate_id
              ▼
┌─────────────────────────────────────┐
│ akamai_cloudcertificates_upload_    │
│ signed_certificate                   │ (ACME auto or manual upload)
│  - Uses certificate_id               │
│  - Uploads signed cert               │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  akamai_property                     │
│  - References uploaded certificates  │
│  - Depends on all certificates       │
└─────────────────────────────────────┘
```

## Automation working - hostname references

In the property resource, the `hostnames` block automatically creates edge hostnames:

```hcl
dynamic "hostnames" {
  for_each = var.hostnames
  content {
    cname_from             = hostnames.value
    cname_to               = "${hostnames.value}.edgekey.net"
    cert_provisioning_type = "CCM"
    certificate {
      certRSA   = contains(lookup(var.certificate_types, hostnames.value, []), "RSA") ?
                  akamai_cloudcertificates_certificate.ccm_cert_rsa[hostnames.value].certificate_id : null
      certECDSA = contains(lookup(var.certificate_types, hostnames.value, []), "ECDSA") ?
                  akamai_cloudcertificates_certificate.ccm_cert_ecdsa[hostnames.value].certificate_id : null
    }
  }
}
```

**Explanation**:

- The `hostnames` block in `akamai_property` automatically provisions edge hostnames (no separate resource needed)
- `cname_to` specifies the edge hostname pattern (`.edgekey.net` for Enhanced TLS)
- `akamai_cloudcertificates_certificate.ccm_cert_rsa` creates resources only for hostnames with RSA or ECDSA or both in `certificate_types`
- `[hostnames.value]` accesses the specific certificate instance for the current hostname
- `.certificate_id` retrieves the certificate ID attribute from that instance
- Conditional checks ensure we only reference certificates that were actually created

Example with mixed certificate types:

```hcl
certificate_types = {
  "example.com"     = ["RSA", "ECDSA"]  # Both certificates created
  "www.example.com" = ["RSA"]           # Only RSA created
}
```

- For `example.com`: Both `certRSA` and `certECDSA` reference certificate IDs
- For `www.example.com`: Only `certRSA` references certificate ID, `certECDSA` is null
- Akamai automatically creates `example.com.edgekey.net` and `www.example.com.edgekey.net` when property activates

## Key Variables

| Variable                     | Description                                  | Default      |
| ---------------------------- | -------------------------------------------- | ------------ |
| `hostnames`                  | List of hostnames                            | -            |
| `certificate_types`          | Map of hostname → ["RSA", "ECDSA"] or single | -            |
| `enable_acme_signing`        | Use Let's Encrypt for automatic signing      | -            |
| `upload_signed_certificates` | Enable manual cert upload (external CA)      | -            |
| `certificate_organization`   | Org name for cert subject                    | -            |
| `certificate_state`          | State for cert subject                       | -            |
| `certificate_locality`       | City for cert subject                        | -            |
| `certificate_country_code`   | 2-letter country code                        | -            |
| `secure_network`             | ENHANCED_TLS or STANDARD_TLS                 | ENHANCED_TLS |
| `rsa_key_size`               | RSA key size (2048/4096)                     | 2048         |
| `ecdsa_key_size`             | ECDSA key size (P-256/P-384)                 | P-256        |
| `enable_domain_validation`   | Enable DCV                                   | true         |
| `run_domain_validation`      | Run DCV validation                           | false        |
| `enable_edgedns_auto_dcv`    | Auto-create DCV DNS records in EdgeDNS       | false        |
| `edgedns_zone`               | EdgeDNS zone for auto DCV records            | ""           |
| `edgedns_edgerc_section`     | .edgerc section for EdgeDNS API              | "default"    |

## Certificate Type Selection Examples

```hcl
# Both RSA and ECDSA for all domains
certificate_types = {
  "example.com"     = ["RSA", "ECDSA"]
  "www.example.com" = ["RSA", "ECDSA"]
}

# Mixed configuration
certificate_types = {
  "api.example.com"  = ["RSA"]         # API only needs RSA
  "app.example.com"  = ["ECDSA"]       # Modern app uses ECDSA
  "www.example.com"  = ["RSA", "ECDSA"] # Main site needs both
}

# RSA only for legacy compatibility
certificate_types = {
  "legacy.example.com" = ["RSA"]
}
```

## Important Notes

1. **ACME/Let's Encrypt (Internal Akamai testing)**:
   - Fully automated certificate signing and renewal
   - Uses EdgeDNS to automatically create/remove DNS validation records
   - RSA certificates processed first, then ECDSA (sequential to avoid DNS conflicts)
   - No manual intervention needed after initial `terraform apply`

2. **Certificate Type Flexibility (Customers)**:
   - Choose different certificate types per hostname via `certificate_types` map
   - Not all hostnames need both RSA and ECDSA
   - Property configuration automatically references only the certificates you choose

3. **Dependencies**: The property won't be created until certificates are uploaded (either via ACME or manual upload)

4. **Activation Safety**: Set `activate_to_production = false` initially to test on staging first

5. **Certificate Updates**:
   - ACME: Simply run `terraform apply` to renew
   - Manual: Generate new CSRs, get them signed, and update the signed certificate PEM values

6. **Importing Existing Properties**: If property already exists:

   ```bash
   # Find property ID
   akamai property-manager list-properties --section tc-east | grep -i "your-property-name"

   # Import it
   terraform import akamai_property.this prp_XXXXXX,ctr_xxxxx,grp_zzzzz
   ```

7. **Domain Control Validation (DCV)**:
   - **EdgeDNS Users**: Enable `enable_edgedns_auto_dcv = true` for automatic DNS record creation
   - **External DNS Users**: Set `enable_edgedns_auto_dcv = false` and manually create DNS records from outputs
   - DCV is required for new domains on Akamai network
   - Existing validated domains can skip DCV by setting `enable_domain_validation = false`

## ACME/EdgeDNS Configuration

The ACME provider is configured in `acme.tf`:

```hcl
dns_challenge {
  provider = "edgedns"
  config = {
    AKAMAI_EDGERC         = "~/.edgerc"
    AKAMAI_EDGERC_SECTION = "default"
  }
}
```

Ensure your `.edgerc` file has EdgeDNS permissions for the zone.

## Troubleshooting

### Check certificate status

```bash
terraform output -json ccm_certificate_upload_status
```

### Check DCV validation status

```bash
terraform output -json dcv_validation_status
```

### View all outputs

```bash
terraform output
```

### Force resource recreation

```bash
# If certificates need to be regenerated
terraform taint 'akamai_cloudcertificates_certificate.ccm_cert_rsa["ccm-www.example.com"]'
terraform apply
```

### ACME Certificate Issues

```bash
# Check ACME account registration
terraform state show acme_registration.account

# Check specific certificate
terraform state show 'acme_certificate.certificate_rsa["ccm-www.example.com"]'

# If DNS validation fails, verify EdgeDNS zone exists
akamai edgedns list-zones --section default | grep example.com
```

## Workflow Summary

**With ACME/Let's Encrypt (Recommended)**:

1. Configure `certificate_types` and set `enable_acme_signing = true`
2. Run `terraform apply` - everything happens automatically
3. Activate to production when ready

**With Manual CA**:

1. **First run**: Generate CSRs → Get them signed by CA
2. **Second run**: Upload signed certificates → Create property (without activation)
3. **Third run** (if needed): Add DCV DNS records → Validate domains → Activate

This ensures certificates are properly provisioned before the property is created, maintaining the correct dependency order.
