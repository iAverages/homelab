{
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkMerge [
    (lib.mkIf config.services.openssh.enable {
      services.openssh.settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
      };
      users.users.root.openssh.authorizedKeys.keys =
        pkgs.lib.allPublicKeys;
    })
    (lib.mkIf config.boot.initrd.network.enable {
      boot.initrd.network.ssh.authorizedKeys =
        lib.mkDefault pkgs.lib.allPublicKeys;
    })
  ];
}
