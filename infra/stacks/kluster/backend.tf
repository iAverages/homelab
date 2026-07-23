terraform {
  backend "s3" {
    bucket = "kirsi-terraform"
    key    = "infra/stacks/kluster/terraform.tfstate"
    region = "eu-central-003"
    endpoints = {
      s3 = "https://s3.eu-central-003.backblazeb2.com"
    }
    encrypt      = true
    use_lockfile = false # not supported by b2
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
