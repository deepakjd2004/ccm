
data "akamai_property_rules_builder" "template-web_rule_security" {
  rules_v2025_10_16 {
    name                  = "Security"
    criteria_must_satisfy = "all"
    behavior {
      site_shield {
        ssmap {
          has_mixed_hosts = false
          name            = "s.akamaiedge.net" # Update with correct SSMap name 
          src             = "PREVIOUS_MAP"
          srmap           = "name.akasrg.akamai.com" # Update with correct SRMap hostname
          value           = "s.akamaiedge.net" # Update with correct value hostname
        }
      }
    }
  }
}
