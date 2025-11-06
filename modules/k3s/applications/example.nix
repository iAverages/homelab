{
  services.k3s = {
    autoDeployCharts.hello-world = {
      name = "hello-world";
      repo = "https://helm.github.io/examples";
      version = "0.1.0";
      hash = "sha256-U2XjNEWE82/Q3KbBvZLckXbtjsXugUbK6KdqT5kCccM=";
      values = {
        replicaCount = 3;
        serviceAccount.create = false;
        servcie.port = 8080;
      };
    };
  };
}
