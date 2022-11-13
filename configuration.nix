{ pkgs, config, modulesPath, ... }:

let
  nixos-wsl = import ./default.nix;
in
{
  imports = [
    nixos-wsl.nixosModules.wsl
  ];

  wsl = {
    enable = true;
    nativeSystemd = true;
    wslConf.automount.root = "/mnt";
    wslConf.options = "metadata,uid=1000,gid=100,umask=22,fmask=11,case=dir";
    defaultUser = "nixos";
    startMenuLaunchers = true;

    # Enable native Docker support
    # docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    # docker-desktop.enable = true;

  };

  # Enable nix flakes
  nixpkgs.config.allowUnfree = true;
  nix.autoOptimiseStore = true;
  nix.gc.automatic = true;
  nix.package = pkgs.nixFlakes;
  nix.trustedUsers = [ "root" "$defaultUser" "@wheel" ];
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  system.stateVersion = "22.05";
}
