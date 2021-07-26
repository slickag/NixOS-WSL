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
      vim
      wget
      zip
      zsh
      dos2unix
      tmux
      screen
      wslu
      wsl-open
      socat
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
      wslg-xwayland.enable = true;

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
      initialHashedPassword = "";
      uid = 1000;
      group = "users";
      shell = pkgs.zsh;
      extraGroups = [ "wheel" "lp" "docker" "networkmanager" "audio" "video" "plugdev" "kvm" "cdrom" "bluetooth" ];
    };

    users.users.root = {
      shell = "${syschdemd}/bin/syschdemd";
      initialHashedPassword = "";
      # Otherwise WSL fails to login as root with "initgroups failed 5"
      extraGroups = [ "root" ];
    };

    security.sudo.wheelNeedsPassword = false;

    environment.etc = {
      "wsl.conf" = {
        mode = "0644";
        text = ''
          [automount]
          enabled = true
          options = "metadata"
          crossDistro = true

          [network]
          hostname = nixos

          [interop]
          enabled = true
          appendwindowspath = true

          [boot]
          command = "[ ! -e /run/current-system ] && LANG=C.UTF-8 /nix/var/nix/profiles/system/activate; PATH=${pkgs.systemd}/lib/systemd:$PATH \
                    /run/current-system/sw/bin/unshare --fork --mount-proc --pid --propagation shared -- /bin/sh -c '
                    /nix/var/nix/profiles/system/sw/bin/mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
                    exec systemd --unit=multi-user.target
                    ' &"
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

    environment.shellAliases = {
      diff = "diff --color=auto";
      exa = "exa -gahHF@ --group-directories-first --time-style=long-iso --color-scale --icons --git";
      l = "exa -l $*";
      ll = "lsd -AFl --group-dirs first --total-size $*";
      ls = "exa -lG $*";
      lt = "exa -T $*";
      tree = "tree -a -I .git --dirsfirst $*";
      nixos-rebuild = "sudo nixos-rebuild $*";
      which-command = "whence";
    };


    # Disable systemd units that don't make sense on WSL
    systemd.suppressedSystemUnits = [
      "serial-getty@ttyS0.service"
      "serial-getty@hvc0.service"
      "getty@tty1.service"
      "autovt@.service"
      "systemd-udev-trigger.service"
      "systemd-udevd.service"
      "sys-kernel-debug.mount"
      "console-getty.service"
      "container-getty@.service"
      "getty@.service"
      "serial-getty@.service"
      "getty-pre.target"
      "getty.target"
    ];
    systemd.services.firewall.enable = false;
    systemd.services.systemd-resolved.enable = false;

    # Don't allow emergency mode, because we don't have a console.
    systemd.enableEmergencyMode = false;
  };
}
