
data "akamai_property_rules_builder" "template-web_rule_default" {
  rules_v2025_10_16 {
    name      = "default"
    is_secure = true
    comments  = "The behaviors in the Default Rule apply to all requests for the property hostname(s) unless another rule overrides the Default Rule settings."
    behavior {
      origin {
        cache_key_hostname               = "REQUEST_HOST_HEADER"
        compress                         = true
        custom_valid_cn_values           = ["{{Origin Hostname}}", "{{Forward Host Header}}", ]
        enable_true_client_ip            = true
        forward_host_header              = "REQUEST_HOST_HEADER"
        hostname                         = var.origin_hostname
        http_port                        = 80
        https_port                       = 443
        ip_version                       = "IPV4"
        min_tls_version                  = "DYNAMIC"
        origin_certificate               = ""
        origin_certs_to_honor            = "STANDARD_CERTIFICATE_AUTHORITIES"
        origin_sni                       = true
        origin_type                      = "CUSTOMER"
        ports                            = ""
        standard_certificate_authorities = ["THIRD_PARTY_AMAZON", ]
        tls_version_title                = ""
        true_client_ip_client_setting    = false
        true_client_ip_header            = "True-Client-IP"
        verification_mode                = "CUSTOM"
      }
    }
    behavior {
      cp_code {
        enable_default_content_provider_code = false
        value {
          id           = parseint(replace(var.cp_code_id, "cpc_", ""), 10)
        }
      }
    }
    behavior {
      report {
        custom_log_field     = ""
        log_accept_language  = false
        log_cookies          = "OFF"
        log_custom_log_field = true
        log_edge_ip          = false
        log_host             = true
        log_referer          = true
        log_user_agent       = true
        log_x_forwarded_for  = false
      }
    }
    children = [
      data.akamai_property_rules_builder.template-web_rule_security.json,
      data.akamai_property_rules_builder.template-web_rule_performance.json,
      data.akamai_property_rules_builder.template-web_rule_sure_route.json,
      data.akamai_property_rules_builder.template-web_rule_allow_http_methods.json,
      data.akamai_property_rules_builder.template-web_rule_caching.json,
      data.akamai_property_rules_builder.template-web_rule_redirect_to_https.json,
      data.akamai_property_rules_builder.template-web_rule_akamai-_reference_no.json,
    ]
  }
}
