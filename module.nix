{ lib, pkgs, config, modulesPath, ... }:
with lib;
let
  cfg = config.boot.wsl;
  syschdemd = import ./etcNixos/wsl/syschdemd.nix {
    inherit lib pkgs config;
    defaultUser = cfg.user;
  };
in
{
  imports = [ ./build-tarball.nix ./etcNixos/wsl/wslg-xwayland.nix ];

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
      trustedUsers = [ "root" "${cfg.user}" ];
      extraOptions = ''
        experimental-features = nix-command flakes ca-references
        builders-use-substitutes = true
      '';
      distributedBuilds = true;
    };

    # WSL is closer to a container than anything else
    boot.isContainer = true;
    boot.enableContainers = true;
    boot.cleanTmpDir = true;
    boot.tmpOnTmpfs = true;

    environment.systemPackages = with pkgs; [
      nixFlakes
      git
      bat
      binutils
      coreutils
      curl
      exa
      lsd
      man
      fd
      fzf
      iptables
      procs
      unzip
      wget
      zip
      zsh
      dos2unix
      screen
      wslu
      wsl-open
      bc
      socat
      rclone
      xclip
      aria2
    ];

    programs = {
      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestions.enable = true;
        setOptions = [ "EXTENDED_HISTORY" ];
      };
      bash.enableCompletion = true;
      command-not-found.enable = true;
      dconf.enable = true;
      mtr.enable = true;
      fuse.userAllowOther = true;
      tmux.enable = true;
      xwayland.enable = true;
    };

    services = {
      samba.enable = false;
      blueman.enable = false;
      printing.enable = false;
      wslg-xwayland.enable = true;
      journald.extraConfig = ''
        MaxRetentionSec=1week
        SystemMaxUse=200M
      '';
    };

    # Set your time zone.
    time.timeZone = "America/Phoenix";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      keyMap = "us";
    };

    networking.dhcpcd.enable = false;
    powerManagement.enable = false;

    system.autoUpgrade = {
      enable = true;
      allowReboot = false;
      channel = https://nixos.org/channels/nixos-unstable;
    };

    users = {
      mutableUsers = true;
      users = {
        ${cfg.user} = {
          isNormalUser = true;
          initialHashedPassword = "";
          uid = 1000;
          group = "users";
          shell = pkgs.zsh;
          extraGroups = [ "wheel" "lp" "docker" "networkmanager" "audio" "video" "plugdev" "kvm" "cdrom" "bluetooth" ];
        };
        root = {
          shell = "${defaultUser}/bin/syschdemd";
          initialHashedPassword = "";
          # Otherwise WSL fails to login as root with "initgroups failed 5"
          extraGroups = [ "root" ];
        };
      };
    };

    security.sudo.wheelNeedsPassword = false;
    security.sudo.execWheelOnly = true;

    environment.etc = {
      hosts.enable = false;
      "resolv.conf".enable = false;
      "wsl.conf" = {
        mode = "0644";
        text = ''
          [automount]
          enabled = true
          options = "metadata,uid=1000,gid=100,umask=0022,fmask=11,case=dir"
          crossDistro = true

          [network]
          hostname = nixos

          [interop]
          enabled = true
          appendwindowspath = true

          [filesystem]
          umask = 0022
        '';
      };
      "ld.so.conf.d/ld.wsl.conf" = {
        mode = "0644";
        text = ''
          # This file was automatically generated by WSL. To stop automatic generation of this file, add the following entry to /etc/wsl.conf:
          # [automount]
          # ldconfig = false
          /usr/lib/wsl/lib
        '';
      };
    };

    environment = {
      shellInit = ''
        export PATH=$PATH:/bin:/sbin:/usr/lib/wsl/lib
      '';
      shellAliases = {
        diff = "diff --color=auto";
        exa = "exa -gahHF@ --group-directories-first --time-style=long-iso --color-scale --icons --git";
        l = "exa -l";
        ll = "lsd -AFl --group-dirs first --total-size";
        ls = "exa -lG";
        lt = "exa -T";
        tree = "tree -a -I .git --dirsfirst";
        nixos-rebuild = "sudo nixos-rebuild";
        which-command = "whence";
      };
    };

    # Disable systemd units that don't make sense on WSL
    systemd.suppressedSystemUnits = [
      "autovt@.service"
      "systemd-udev-settle.service"
      "systemd-udev-trigger.service"
      "systemd-udevd.service"
      "systemd-udevd-control.socket"
      "systemd-udevd-kernel.socket"
      "systemd-networkd.service"
      "systemd-networkd-wait-online.service"
      "networkd-dispatcher.service"
      "systemd-resolved.service"
      "ModemManager.service"
      "NetworkManager.service"
      "NetworkManager-wait-online.service"
      "pulseaudio.service"
      "pulseaudio.socket"
      "sys-kernel-debug.mount"
    ];

    systemd.services.firewall.enable = false;
    systemd.services."serial-getty@ttyS0".enable = false;
    systemd.services."serial-getty@hvc0".enable = false;
    systemd.services."getty@tty1".enable = false;
    systemd.services.systemd-resolved.enable = false;

    # Don't allow emergency mode, because we don't have a console.
    systemd.enableEmergencyMode = false;
  };
}
