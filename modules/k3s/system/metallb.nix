{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.metallb;
in {
  options.homelab.metallb = {
    enable = lib.mkEnableOption "metallb";
    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  # config.services.k3s = lib.mkIf cfg.enable {
  config.services.k3s.autoDeployCharts.metallb = lib.mkIf cfg.enable {
    name = "metallb";
    repo = "https://metallb.github.io/metallb";
    version = "0.15.2";
    hash = "sha256-Tw/DE82XgZoceP/wo4nf4cn5i8SQ8z9SExdHXfHXuHM=";
    targetNamespace = "metallb-system";
    createNamespace = true;

    extraDeploy = [
      {
        apiVersion = "metallb.io/v1beta1";
        kind = "IPAddressPool";
        metadata = {
          name = "k3s-pool";
          namespace = "metallb-system";
        };
        spec = {
          addresses = config.homelab.metallb.addresses;
        };
      }
      {
        apiVersion = "metallb.io/v1beta1";
        kind = "L2Advertisement";
        metadata = {
          name = "k3s-l2advertisment";
          namespace = "metallb-system";
        };
        spec = {
          ipAddressPools = ["k3s-pool"];
        };
      }
    ];
  };
}
