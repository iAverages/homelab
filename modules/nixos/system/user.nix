{
  config,
  lib,
  pkgs,
  ...
}: {
  options.dan = lib.mkOption {
    type = lib.types.bool;
    description = "dan";
    default = true;
  };

  config = lib.mkIf config.dan {
    users.users.dan = {
      isNormalUser = true;
      description = "dan";
      extraGroups = ["networkmanager" "wheel"];
      hashedPasswordFile = config.sops.secrets.danPassword.path;
      openssh.authorizedKeys.keys = pkgs.lib.allPublicKeys;
    };
  };
}
