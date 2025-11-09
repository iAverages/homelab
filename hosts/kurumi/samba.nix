{
  config,
  options,
  pkgs,
  lib,
  ...
}: let
  shares = {
    global = {
      "pam password change" = "yes";
      "min protocol" = "SMB2";
    };
    data = {
      path = "/opt/data";
      browseable = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "create mask" = "0644";
      "directory mask" = "0755";
      dirPerm = "0770";
      filePerm = "0660";
      owner = "root";
      group = "samba";
    };
  };

  # sambaEnabledUsers =
  #   config.users.users
  #   |> lib.filterAttrs (name: user: (user.samba or {}).allowedShares or [] != []);

  # getValidUsersForShare = shareName: let
  #   filteredUsers =
  #     sambaEnabledUsers
  #     |> lib.filterAttrs (name: user: lib.elem shareName (user.samba.allowedShares or []));
  # in
  #   lib.concatStringsSep " " (lib.attrNames filteredUsers);

  sambaEnabledUsers = config.samba.users;

  getValidUsersForShare = shareName: let
    filteredUsers =
      sambaEnabledUsers
      |> lib.filterAttrs (name: user: lib.elem shareName (user.allowedShares or []));
  in
    lib.concatStringsSep " " (lib.attrNames filteredUsers);

  sambaShareConfigs =
    lib.mapAttrs (
      name: shareConfig:
        shareConfig
        // {
          "valid users" = getValidUsersForShare name;
        }
    )
    shares;
in {
  options.samba.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        passwordFile = lib.mkOption {
          type = lib.types.path;
          description = "The path for the hashed password for this user.";
        };

        allowedShares = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "The path for this Samba user.";
        };
      };
    });
    default = {};
    description = "Samba user configurations.";
  };
  # options.samba._each.options.allowedShares = lib.mkOption {
  #   type = lib.types.attrs;
  #   default = {};
  #   description = "Extra options for user, to be interpreted by other modules.";
  # };

  config = {
    services = {
      samba = {
        package = pkgs.samba4Full;
        enable = true;
        openFirewall = true;
        settings =
          sambaShareConfigs;

        # data = {
        #   path = "/opt/data";
        #   writable = "true";
        # };
      };
      # for auto discovery
      avahi = {
        enable = true;
        publish.enable = true;
        publish.userServices = true;
        nssmdns4 = true;
        openFirewall = true;
      };
      samba-wsdd = {
        enable = true;
        openFirewall = true;
      };
    };

    systemd.services.set-samba-passwords = {
      enable = true;
      description = "set samba passwords for users";
      after = ["sops-install-secrets.service"];
      requires = ["sops-install-secrets.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: userConfig: ''
          # The password needs to be passed twice
          /run/current-system/sw/bin/printf \
            "$(/run/current-system/sw/bin/cat ${userConfig.passwordFile})\n$(/run/current-system/sw/bin/cat ${userConfig.passwordFile})\n" \
            | /run/current-system/sw/bin/smbpasswd -sa ${name}
        '')
        sambaEnabledUsers);
    };
  };
}
