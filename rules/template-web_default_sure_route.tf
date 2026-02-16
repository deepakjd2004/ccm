
data "akamai_property_rules_builder" "template-web_rule_sure_route" {
  rules_v2025_10_16 {
    name                  = "SureRoute"
    comments              = "Set the SureRoute behaviour for Prod"
    criteria_must_satisfy = "all"
    template_link         = ""
    behavior {
      sure_route {
        custom_map             = "akasrg.akamai.com" # Update with correct custom map hostname
        enable_custom_key      = false
        enabled                = true
        force_ssl_forward      = true
        race_stat_ttl          = "30m"
        sr_download_link_title = ""
        test_object_url        = "/sureroute-object.html" # Ensure this test object exists on the origin server for accurate SureRoute testing
        to_host_status         = "INCOMING_HH"
        type                   = "CUSTOM_MAP"
      }
    }
  }
}
