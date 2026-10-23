{
  disko.devices = {
    disk.nvme0 = {
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
              mountOptions = ["umask=0077"];
            };
          };
          swap = {
            size = "16G";
            content = {
              type = "swap";
              randomEncryption = true;
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
    zpool.zroot = {
      type = "zpool";
      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        # disko reads the passphrase from here during install, boot prompts for it
        keylocation = "file:///tmp/secret.key";
        "com.sun:auto-snapshot" = "true";
      };
      postCreateHook = ''
        zfs set keylocation=prompt zroot
      '';
      options.ashift = "12";
      datasets = {
        "root" = {
          type = "zfs_fs";
          mountpoint = "/";
        };
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options."com.sun:auto-snapshot" = "false";
        };
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
        };
      };
    };
  };
}
