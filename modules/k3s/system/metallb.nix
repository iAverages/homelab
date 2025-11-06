{
  lib,
  config,
  ...
}: {
  options.homelab.metallb.addresses = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
  };

  config.services.k3s.autoDeployCharts.metallb = {
    name = "metallb";
    repo = "https://metallb.github.io/metallb";
    version = "6.4.22";
    hash = "";
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
