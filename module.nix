{ lib, pkgs, config, modulesPath, ... }:
with lib;
let
  cfg = config.boot.wsl;
  syschdemd = import ./syschdemd.nix {
    inherit lib pkgs config;
    defaultUser = cfg.user;
  };
in
{
  imports = [ ./build-tarball.nix ];

  options.boot.wsl = {
    enable = mkEnableOption "Windows WSL support";
    user = mkOption {
      type = types.str;
      default = "nixos";
    };
  };
  config = mkIf cfg.enable {
    nix = {
      autoOptimiseStore = true;
      gc.automatic = true;
      package = pkgs.nixUnstable;
      trustedUsers = [ "${cfg.user}" ];
      extraOptions = ''
        experimental-features = nix-command flakes ca-references
        builders-use-substitutes = true
      '';
      distributedBuilds = true;
    };
    # WSL is closer to a container than anything else
    boot.isContainer = true;
    boot.enableContainers = true;

    environment.systemPackages = with pkgs; [
      nixFlakes
      git
      bat
      binutils
      coreutils
      curl
      exa
      lsd
      fd
      fzf
      iptables
      procs
      unzip
      vim
      wget
      zip
      zsh
      dos2unix
      tmux
      screen
    ];

    programs = {
      zsh = {
        enable = true;
        enableCompletion = true;
      };
      bash.enableCompletion = true;
      fuse.userAllowOther = true;
    };

    services = {
      samba.enable = false;
      blueman.enable = false;
      printing.enable = false;

      journald.extraConfig = ''
        MaxRetentionSec=1week
        SystemMaxUse=200M
      '';
    };

    # Set your time zone.
    time.timeZone = "America/Phoenix";

    boot.cleanTmpDir = true;
    boot.tmpOnTmpfs = true;
    environment.etc.hosts.enable = false;
    environment.etc."resolv.conf".enable = false;

    networking.dhcpcd.enable = false;

    system.autoUpgrade.enable = true;
    system.autoUpgrade.allowReboot = false;
    system.autoUpgrade.channel = https://nixos.org/channels/nixos-unstable;

    users.mutableUsers = true;
    users.users.${cfg.user} = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      extraGroups = [ "wheel" "lp" "docker" "networkmanager" "audio" "video" "plugdev" "kvm" "cdrom" "bluetooth" ];
    };

    users.users.root = {
      shell = "${syschdemd}/bin/syschdemd";
      # Otherwise WSL fails to login as root with "initgroups failed 5"
      extraGroups = [ "root" ];
    };

    security.sudo.wheelNeedsPassword = false;

    environment.etc."wsl.conf" = {
      text = ''
        [automount]
        enabled = true
        options = "metadata,uid=1000,gid=100,umask=0022,fmask=11,case=off"
        crossDistro = true

        [network]
        hostname = NIXOS

        [interop]
        enabled = true
        appendwindowspath = true

        [filesystem]
        umask = 0022
      '';
    };

    # Disable systemd units that don't make sense on WSL
    systemd.services."serial-getty@ttyS0".enable = false;
    systemd.services."serial-getty@hvc0".enable = false;
    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@".enable = false;

    systemd.services.firewall.enable = false;
    systemd.services.systemd-resolved.enable = false;
    systemd.services.systemd-udevd.enable = false;

    # Don't allow emergency mode, because we don't have a console.
    systemd.enableEmergencyMode = false;
  };
}
