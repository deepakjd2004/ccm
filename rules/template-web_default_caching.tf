
data "akamai_property_rules_builder" "template-web_rule_caching" {
  rules_v2025_10_16 {
    name                  = "Caching"
    comments              = "Controls caching, which offloads traffic away from the origin. Most objects types are not cached. However, the child rules override this behavior for certain subsets of requests."
    criteria_must_satisfy = "all"
    behavior {
      caching {
        behavior                 = "CACHE_CONTROL_AND_EXPIRES"
        cache_control_directives = ""
        default_ttl              = "0s"
        enhanced_rfc_support     = false
        honor_must_revalidate    = false
        honor_private            = false
        must_revalidate          = false
      }
    }
    behavior {
      cache_error {
        enabled        = true
        preserve_stale = true
        ttl            = "10s"
      }
    }
    behavior {
      downstream_cache {
        allow_behavior = "LESSER"
        behavior       = "ALLOW"
        send_headers   = "CACHE_CONTROL_AND_EXPIRES"
        send_private   = false
      }
    }
    children = [
      data.akamai_property_rules_builder.template-web_rule_css_and_java_script.json,
      data.akamai_property_rules_builder.template-web_rule_static_objects.json,
      data.akamai_property_rules_builder.template-web_rule_uncacheable_responses.json,
      data.akamai_property_rules_builder.template-web_rule_no_cache.json,
    ]
  }
}

data "akamai_property_rules_builder" "template-web_rule_css_and_java_script" {
  rules_v2025_10_16 {
    name                  = "CSS and JavaScript"
    comments              = "Overrides the default caching behavior for CSS and JavaScript objects that are cached on the edge server. Because these object types are dynamic, the TTL is brief."
    criteria_must_satisfy = "any"
    criterion {
      file_extension {
        match_case_sensitive = false
        match_operator       = "IS_ONE_OF"
        values               = ["css", "js", ]
      }
    }
    behavior {
      caching {
        behavior        = "MAX_AGE"
        must_revalidate = true
        ttl             = "1d"
      }
    }
    behavior {
      prefresh_cache {
        enabled     = true
        prefreshval = 90
      }
    }
    behavior {
      prefetchable {
        enabled = true
      }
    }
  }
}

data "akamai_property_rules_builder" "template-web_rule_static_objects" {
  rules_v2025_10_16 {
    name = "Static Objects"
    comments = trimsuffix(<<EOT
Overrides the default caching behavior for images, music, and similar objects that are cached on the edge server. Because these object types are static, the TTL is long.

Don't prefetch all objects unless already prefetchable.
EOT
    , "\n")
    criteria_must_satisfy = "any"
    criterion {
      file_extension {
        match_case_sensitive = false
        match_operator       = "IS_ONE_OF"
        values               = ["aif", "aiff", "au", "avi", "bin", "bmp", "cab", "carb", "cct", "cdf", "class", "dcr", "dtd", "exe", "flv", "gcf", "gff", "gif", "grv", "hdml", "hqx", "ico", "ini", "jpeg", "jpg", "mov", "mp3", "nc", "pct", "png", "ppc", "pws", "swa", "swf", "vbs", "w32", "wav", "wbmp", "wml", "wmlc", "wmls", "wmlsc", "xsd", "zip", "pict", "tif", "tiff", "mid", "midi", "ttf", "eot", "woff", "woff2", "otf", "svg", "svgz", "webp", "jxr", "jar", "jp2", "hdp", "wdp", ]
      }
    }
    behavior {
      caching {
        behavior        = "MAX_AGE"
        must_revalidate = true
        ttl             = "7d"
      }
    }
    behavior {
      prefresh_cache {
        enabled     = true
        prefreshval = 90
      }
    }
    behavior {
      prefetchable {
        enabled = true
      }
    }
    behavior {
      prefetch {
        enabled = false
      }
    }
  }
}

data "akamai_property_rules_builder" "template-web_rule_uncacheable_responses" {
  rules_v2025_10_16 {
    name = "Uncacheable Responses"
    comments = trimsuffix(<<EOT
(Dynamic content)

Overrides the default downstream caching behavior for uncacheable object types. Instructs the edge server to pass Cache-Control and/or Expire headers from the origin to the client.
EOT
    , "\n")
    criteria_must_satisfy = "all"
    criterion {
      cacheability {
        match_operator = "IS_NOT"
        value          = "CACHEABLE"
      }
    }
    behavior {
      downstream_cache {
        behavior = "TUNNEL_ORIGIN"
      }
    }
  }
}

data "akamai_property_rules_builder" "template-web_rule_no_cache" {
  rules_v2025_10_16 {
    name                  = "No Cache"
    comments              = "Don't cache frequently changing system info."
    criteria_must_satisfy = "all"
    criterion {
      filename {
        match_case_sensitive = true
        match_operator       = "IS_ONE_OF"
        values               = ["x-s.txt", "x-v.txt", ]
      }
    }
    behavior {
      caching {
        behavior = "NO_STORE"
      }
    }
    behavior {
      downstream_cache {
        behavior = "BUST"
      }
    }
  }
}
