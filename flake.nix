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

        # devShell と Docker で共有するパッケージ集合
        commonPackages = with pkgs; [
          coreutils
          bash
          git
          gnumake
          perl
          inkscape
          texliveEnv
        ];

        # Dockerイメージのビルド定義
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "semi-latex-builder";
          tag = "latest";

          contents = commonPackages;

          config = {
            Cmd = [ "bash" ];
            WorkingDir = "/work";
            Env = [
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "TEXMFHOME=/work/texmf"
              "TEXMFVAR=/work/.texlive-var"
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
          packages = commonPackages;
          shellHook = ''
            export TEXMFHOME=$PWD/texmf
            export TEXMFVAR=$PWD/.texlive-var
          '';
        };
      }
    );
}
