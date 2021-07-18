{ ... }: {
  boot.wsl.enable = true;
  boot.wsl.etcNixos = ./etcNixos;
  boot.wsl.user = "slick";
}
