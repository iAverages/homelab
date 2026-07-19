locals {
  group_name = "kluster"
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

module "deploy" {
  for_each = local.hosts
  source   = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = ".#nixosConfigurations.${each.value.hostname}.config.system.build.toplevel"
  nixos_partitioner_attr = ".#nixosConfigurations.${each.value.hostname}.config.system.build.diskoScript"

  target_host  = each.value.ipv4
  install_user = each.value.install_user
  target_user  = each.value.target_user
  instance_id  = each.value.instance_id

  copy_host_keys             = true
  nixos_generate_config_path = "${local.hosts_root}/${each.value.hostname}/hardware-configuration.nix"

  extra_files_script = "${path.module}/prepare-extra-files.sh"
  extra_environment = {
    TAKINA_SOPS_KEY_FILE = "" # replace if reinstalling
  }
}
