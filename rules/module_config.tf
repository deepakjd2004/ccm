terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 9.3.0"
    }
  }
  required_version = ">= 1.0"
}

variable "cp_code_id" {
  description = "CP Code ID from root module"
  type        = string
}

variable "origin_hostname" {
  description = "Origin hostname"
  type        = string
}

output "rules" {
  value = data.akamai_property_rules_builder.template-web_rule_default.json
}

output "rule_format" {
  value = data.akamai_property_rules_builder.template-web_rule_default.rule_format
}