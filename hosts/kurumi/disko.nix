{config, ...}: {
  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["nofail"];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };

      sda = {
        type = "disk";
        device = "/dev/sda"; # Replace with your actual device path
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "dataPool";
            };
          };
        };
      };
      sdb = {
        type = "disk";
        device = "/dev/sdb"; # Replace with your actual device path
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "dataPool";
            };
          };
        };
      };
      sdc = {
        type = "disk";
        device = "/dev/sdc"; # Replace with your actual device path
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "dataPool";
            };
          };
        };
      };
      sdd = {
        type = "disk";
        device = "/dev/sdd"; # Replace with your actual device path
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "dataPool";
            };
          };
        };
      };
    };
    zpool = {
      zroot = {
        type = "zpool";
        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          "com.sun:auto-snapshot" = "true";
        };
        options.ashift = "12";
        datasets = {
          "root" = {
            type = "zfs_fs";
            options = {
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "prompt";
            };
            mountpoint = "/";
          };
          "root/nix" = {
            type = "zfs_fs";
            options.mountpoint = "/nix";
            mountpoint = "/nix";
          };
        };
      };
      dataPool = {
        type = "zpool";
        mode = {
          topology = {
            type = "raidz1";
            members = [
              "sda"
              "sdb"
              "sdc"
              "sdd"
            ];
          };
        };

        rootFsOptions = {
          compression = "lz4";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          ashift = "12";
          encryption = "on";
          keylocation = config.sops.secrets.zfsDataPoolKey.path;
          keyformat = "raw";
        };
        datasets = {
          "data" = {
            type = "zfs_fs";
            mountpoint = "/mnt/data";
            options = {
              compression = "zstd";
            };
          };
          "backups" = {
            type = "zfs_fs";
            mountpoint = "/mnt/backups";
            options = {
              compression = "zstd-1";
            };
          };
        };
      };
    };
  };
}
