{
  lib,
  config,
  ...
}: {
  imports = [./applications];

  options = {
    homelab = {
      domain = lib.mkOption {
        type = lib.types.str;
      };
    };
  };
}
