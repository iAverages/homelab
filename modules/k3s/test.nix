{
  services.k3s = {
    manifests = {
      tailnet-service-test.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "tailnet-service-test";
          annotations = {
            "tailscale.com/tailnet-fqdn" = "mysql-database.tail08ef9.ts.net";
          };
        };

        spec = {
          type = "ExternalName";
          externalName = "placeholder"; # required but ignored
        };
      };
    };
  };
}
