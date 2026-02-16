
data "akamai_property_rules_builder" "template-web_rule_allow_http_methods" {
  rules_v2025_10_16 {
    name                  = "Allow HTTP Methods"
    comments              = "Allows the ability to enable request methods—configured in child rules."
    criteria_must_satisfy = "all"
    behavior {
      all_http_in_cache_hierarchy {
        enabled = true
      }
    }
  }
}
