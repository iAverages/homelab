{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl = {
    enable = true;
    defaultUser = "dan";
  };

  networking.hostName = "kirsi-wsl";
  nixpkgs.hostPlatform = "x86_64-linux";

  sops = {
    defaultSopsFile = ../../secrets/personal.yaml;
    age = {
      sshKeyPaths = ["/home/dan/.ssh/kirsi-wsl_ed25519"];
      keyFile = "/home/dan/.config/sops/age/keys.txt";
    };
    secrets.danPassword.neededForUsers = true;
  };

  nix.package = pkgs.lixPackageSets.stable.lix;

  boot.tmp.useTmpfs = true;
  # wsl syncs time from the windows host
  services.timesyncd.enable = lib.mkForce false;

  locale.gb.enable = true;
  security.sudo-rs.enable = true;
  security.pki.certificateFiles = [../../secrets/dan-lan-ca.crt];

  environment.variables.NH_FLAKE = "/home/dan/homelab";
  services.dbus.implementation = lib.mkForce "broker";

  users.users.dan.shell = pkgs.zsh;

  programs = {
    zsh.enable = true;
    nix-ld.enable = true;
    gnupg.agent.enable = true;
  };

  services = {
    tailscale.enable = true;
    userborn.enable = true;
  };
}
