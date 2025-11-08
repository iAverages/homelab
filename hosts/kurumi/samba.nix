{
  config,
  pkgs,
  lib,
  ...
}: let
  shares = {
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

  sambaEnabledUsers =
    config.users.users
    |> lib.filterAttrs (name: user: (user.samba or {}).allowedShares or [] != []);

  getValidUsersForShare = shareName: let
    filteredUsers =
      sambaEnabledUsers
      |> lib.filterAttrs (name: user: lib.elem shareName (user.samba.allowedShares or []));
  in
    lib.concatStringsSep " " (lib.attrNames filteredUsers);

  # Generate Samba share configurations dynamically
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
  services = {
    samba = {
      package = pkgs.samba4Full;
      enable = true;
      openFirewall = true;
      shares.data = {
        path = "/opt/data";
        writable = "true";
      };
      extraConfig = ''
        server smb encrypt = required
        server min protocol = SMB3_00
      '';
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
}
