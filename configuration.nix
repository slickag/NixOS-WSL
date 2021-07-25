{ ... }: {
  boot.wsl.enable = true;
  boot.wsl.user = "nixos";
  boot.wsl.etcNixos = ./etcNixos;
}
