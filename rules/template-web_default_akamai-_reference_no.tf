
data "akamai_property_rules_builder" "template-web_rule_akamai-_reference_no" {
  rules_v2025_10_16 {
    name                  = "Akamai-Reference no"
    criteria_must_satisfy = "all"
    behavior {
      global_request_number {
        header_name   = "Akamai-GRN"
        output_option = "RESPONSE_HEADER"
      }
    }
  }
}
