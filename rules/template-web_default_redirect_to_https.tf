
data "akamai_property_rules_builder" "template-web_rule_redirect_to_https" {
  rules_v2025_10_16 {
    name                  = "Redirect to HTTPS"
    criteria_must_satisfy = "all"
    criterion {
      request_protocol {
        value = "HTTP"
      }
    }
    behavior {
      redirect {
        destination_hostname  = "SAME_AS_REQUEST"
        destination_path      = "SAME_AS_REQUEST"
        destination_protocol  = "HTTPS"
        mobile_default_choice = "DEFAULT"
        query_string          = "APPEND"
        response_code         = 301
      }
    }
  }
}
