
data "akamai_property_rules_builder" "template-web_rule_performance" {
  rules_v2025_10_16 {
    name                  = "Performance"
    comments              = "Improves the performance of delivering objects to end users. Behaviors in this rule are applied to all requests as appropriate."
    criteria_must_satisfy = "all"
    behavior {
      enhanced_akamai_protocol {
        display = ""
      }
    }
    behavior {
      http2 {
        enabled = ""
      }
    }
    behavior {
      allow_transfer_encoding {
        enabled = true
      }
    }
    behavior {
      remove_vary {
        enabled = true
      }
    }
    behavior {
      prefetch {
        enabled = true
      }
    }
    behavior {
      dns_async_refresh {
        enabled = true
        timeout = "2h"
      }
    }
    behavior {
      adaptive_acceleration {
        ab_logic                  = "DISABLED"
        ab_testing                = ""
        compression               = ""
        enable_brotli_compression = true
        enable_for_noncacheable   = true
        enable_preconnect         = false
        enable_push               = false
        enable_ro                 = false
        preload_enable            = false
        source                    = "MPULSE"
        title_brotli              = ""
        title_http2_server_push   = ""
        title_preconnect          = ""
        title_preload             = ""
        title_ro                  = ""
      }
    }
    children = [
      data.akamai_property_rules_builder.template-web_rule_compressible_objects.json,
    ]
  }
}

data "akamai_property_rules_builder" "template-web_rule_compressible_objects" {
  rules_v2025_10_16 {
    name                  = "Compressible Objects"
    comments              = "Compresses content to improve performance of clients with slow connections. Applies Last Mile Acceleration to requests when the returned object supports gzip compression."
    criteria_must_satisfy = "all"
    criterion {
      content_type {
        match_case_sensitive = false
        match_operator       = "IS_ONE_OF"
        match_wildcard       = true
        values               = ["text/*", "application/javascript", "application/x-javascript", "application/x-javascript*", "application/json", "application/x-json", "application/*+json", "application/*+xml", "application/text", "application/vnd.microsoft.icon", "application/vnd-ms-fontobject", "application/x-font-ttf", "application/x-font-opentype", "application/x-font-truetype", "application/xmlfont/eot", "application/xml", "font/opentype", "font/otf", "font/eot", "image/svg+xml", "image/vnd.microsoft.icon", "text/html*", "text/css*", "application/javascript*", ]
      }
    }
    behavior {
      gzip_response {
        behavior = "ALWAYS"
      }
    }
  }
}
