locals {
  group_name = "nas"
  hosts_root = abspath("${path.root}/../../../hosts")
  host_files = fileset(local.hosts_root, "**/host.tf.json")

  decoded_hosts = {
    for host_file in local.host_files :
    host_file => jsondecode(file("${local.hosts_root}/${host_file}"))
  }

  hosts = {
    for host_file, host in local.decoded_hosts :
    host_file => host
    if try(host.group, "") == local.group_name
  }
}

module "system_build" {
  for_each  = local.hosts
  source    = "github.com/nix-community/nixos-anywhere//terraform/nix-build"
  attribute = ".#nixosConfigurations.${each.value.hostname}.config.system.build.toplevel"
}

module "deploy" {
  for_each     = local.hosts
  source       = "github.com/nix-community/nixos-anywhere//terraform/nixos-rebuild"
  nixos_system = module.system_build[each.key].result.out
  target_host  = each.value.ipv4
  target_user  = each.value.user
}
