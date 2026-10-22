# nixconf

[nixos](https://nixos.org/) config for my homelab servers and personal machines.

## hosts

| host | what it is |
| --- | --- |
| `kirsi` | desktop |
| `izanami` | framework 16 laptop |
| `kirsi-wsl` | nixos on wsl |
| `kurumi` | nas, runs k3s for home stuff |
| `takina` | k3s server |
| `shuna` | vps running slskd |

## layout

- `hosts/` - one folder per machine
- `modules/nixos/` - system modules
- `modules/home/` - home-manager modules
- `modules/k3s/` - k3s apps and services, enabled per host under `homelab.*`
- `infra/stacks/` - opentofu stacks that deploy hosts with nixos-anywhere
- `secrets/` and `hosts/*/secrets/` - encrypted with sops

## usage

the flake uses pipe operators, so you need `pipe-operators` (nix) or `pipe-operator` (lix) in `experimental-features`.

rebuild a machine:

```sh
sudo nixos-rebuild switch --flake .#<host>
# or
nh os switch
```

home-manager on `kirsi`, `izanami` and `kirsi-wsl` is standalone:

```sh
home-manager switch --flake .#dan@<host>
# or
nh home switch
```

deploy servers:

```sh
nix develop
cd infra/stacks/<stack>
tofu apply
```

`tofu` here is a wrapper in `scripts/` that loads the backend secrets with sops first.

build the installer iso:

```sh
nix build .#nixosconfigurations.remote-setup.config.system.build.isoimage
```
