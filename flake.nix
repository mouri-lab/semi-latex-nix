{
  description = "LaTeX build environment for semi-latex-mk2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # 日本語環境を含むTeXLive環境
        texliveEnv = pkgs.texlive.combined.scheme-full;

        # Dockerイメージのビルド定義
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "semi-latex-builder";
          tag = "latest";

          contents = [
            pkgs.coreutils
            pkgs.bash
            pkgs.git
            pkgs.gnumake
            pkgs.perl # latexmkに必要
            pkgs.inkscape # svgパッケージに必要
            texliveEnv
          ];

          config = {
            Cmd = [ "bash" ];
            WorkingDir = "/work";
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            ];
          };
        };
      in
      {
        packages = {
          default = dockerImage;
          dockerImage = dockerImage;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            texliveEnv
            pkgs.inkscape
          ];
        };
      }
    );
}
