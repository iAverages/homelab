locals {
  host_files = fileset(".", "../hosts/**/host.tf.json")
  hosts = {
    for file in local.host_files :
    file => jsondecode(file(file))
  }
}

# TODO: work out if it is possible to migrate to using all-in-one so I can use it for new system deployments
# module "deploy" {
#   for_each                   = local.hosts
#   source                     = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
#   nixos_system_attr      = ".#nixosConfigurations.${each.value.hostname}.config.system.build.toplevel"
#   nixos_partitioner_attr = ".#nixosConfigurations.${each.value.hostname}.config.system.build.diskoScript"
#   target_host                = each.value.ipv4
#   instance_id                = each.value.ipv4
#   nixos_generate_config_path = format("%s/hardware-configuration.nix", trimsuffix(each.key, "host.tf.json"))
# }

module "system-build" {
  for_each  = local.hosts
  source    = "github.com/nix-community/nixos-anywhere//terraform/nix-build"
  attribute = ".#nixosConfigurations.${each.value.hostname}.config.system.build.toplevel"
}

module "deploy" {
  for_each     = local.hosts
  source       = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild"
  nixos_system = module.system-build[each.key].result.out
  target_host  = each.value.ipv4
  target_user = each.value.user
}
