{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.framework-16-7040-amd
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking.hostName = "izanami";
  networking.hostId = "fbac71d9";

  sops = {
    defaultSopsFile = ../../secrets/personal.yaml;
    age = {
      sshKeyPaths = ["/home/dan/.ssh/izanami_ed25519"];
      keyFile = "/home/dan/.config/sops/age/keys.txt";
    };
    secrets.danPassword.neededForUsers = true;
  };

  nix.package = pkgs.lixPackageSets.stable.lix;

  boot = {
    initrd.systemd.enable = true;
    plymouth.enable = true;
    tmp.useTmpfs = true;
    zfs.forceImportRoot = false;
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        maxGenerations = 10;
        secureBoot = {
          enable = true;
          autoGenerateKeys = true;
          autoEnrollKeys.enable = true;
        };
        extraConfig = ''
          remember_last_entry: yes
        '';
      };
    };
  };

  hardware = {
    bluetooth.enable = true;
  };

  locale.gb.enable = true;
  security.sudo-rs.enable = true;
  security.pki.certificateFiles = [../../secrets/dan-lan-ca.crt];

  networking = {
    pihole-dns = {
      enable = true;
      cloudflareFallback = true;
    };
    resolvconf.enable = false;
  };

  environment.variables.NH_FLAKE = "/home/dan/nixconf";

  users.users.dan = {
    shell = pkgs.zsh;
    extraGroups = ["libvirtd"];
  };

  programs = {
    zsh.enable = true;
    dconf.enable = true;
    hyprland.enable = true;
    thunar.enable = true;
    nix-ld.enable = true;
    gnupg.agent.enable = true;
    steam.enable = true;
  };

  services = {
    tailscale.enable = true;
    mullvad-vpn.enable = true;
    userborn.enable = true;
    pipewire.enable = true;
    kanata.enable = true;
    zfs.autoScrub.enable = true;

    dbus = {
      implementation = lib.mkForce "broker";
      packages = [pkgs.dconf];
    };
  };

  virtualisation = {
    docker.enable = true;
    waydroid.enable = true;
  };

  systemd.timers.weekly-update = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "Sun 04:00";
      WakeSystem = true;
      Persistent = true;
    };
  };

  systemd.services.weekly-update = {
    path = with pkgs; [config.nix.package git home-manager networkmanager util-linux];
    serviceConfig.Type = "oneshot";
    script = let
      update = pkgs.writeShellScript "weekly-update" ''
        set -e
        as_dan() { runuser -u dan -- env HOME=/home/dan XDG_RUNTIME_DIR=/run/user/$(id -u dan) "$@"; }
        nm-online -q -t 120
        cd /home/dan/nixconf
        as_dan git pull --ff-only https://github.com/iAverages/nixconf.git main
        system=$(as_dan nix build --no-link --print-out-paths .#nixosConfigurations.izanami.config.system.build.toplevel)
        nix-env -p /nix/var/nix/profiles/system --set "$system"
        "$system/bin/switch-to-configuration" switch
        as_dan home-manager switch --flake .#dan@izanami
      '';
    in ''
      resumed=$(systemctl show sleep.target -P InactiveEnterTimestamp --timestamp=unix)
      resumed=''${resumed#@}
      if systemctl is-active -q sleep.target || (( $(date +%s) - ''${resumed:-0} < 600 )); then
        trap 'systemctl suspend' EXIT
      fi
      if systemd-ac-power; then
        systemd-inhibit --what=sleep:handle-lid-switch --why="weekly update" ${update}
      fi
    '';
  };

  services.udev.packages = [pkgs.via];
  environment.systemPackages = with pkgs; [
    via
    vial
    wine
    swtpm
  ];
}
