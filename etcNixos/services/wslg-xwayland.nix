{config, pkgs, lib, ...}:

let
  cfg = config.services.wslg-xwayland;
in

with lib;

{
  options = {
    services.wslg-xwayland = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = ''
          Enable WSL2 Wayland service/socket.
	'';
      };
    };
  };
  config = mkIf cfg.enable {
    systemd.services.wslg-xwayland = {
      wantedBy = [ "multi-user.target" ]; 
      after = [ "wslg-xwayland.socket" ];
      description = "Enables WSL2 Wayland capabilities.";
      serviceConfig = {
        ExecStart = ''${pkgs.systemd}/lib/systemd/systemd-socket-proxyd /mnt/wslg/.X11-unix/X0'';
      };
      unitConfig = {
        Requires = "wslg-xwayland.socket";
        After = "wslg-xwayland.socket";
      };
    };
    systemd.sockets.wslg-xwayland = {
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      requires = [ "systemd-tmpfiles-setup.service" ];
      listenStreams = [
        "/tmp/.X11-unix/X0"
      ];
      wants = [ "wslg-xwayland.service" ];
    };

    environment.systemPackages = [ pkgs.systemd ];
  };
}
