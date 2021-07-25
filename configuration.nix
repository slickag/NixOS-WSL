{ ... }: {
  boot.wsl.enable = true;
  boot.wsl.user = "slick";
  boot.wsl.etcNixos = ./etcNixos;
}
