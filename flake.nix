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

        # 開発環境用 (ホストOSに合わせる)
        texliveEnv = pkgs.texlive.combined.scheme-full;
        
        # Dockerイメージ用 (ホストのアーキテクチャに合わせたLinuxを使用)
        # macOS (darwin) の場合、対応するLinuxアーキテクチャを選択します。
        # これにより、macOS側で linux-builder が有効になっていれば、
        # 自動的に linux-builder に処理が委譲され、Linux用のDockerイメージが生成されます。
        linuxSystem = if builtins.match "aarch64.*" system != null then "aarch64-linux" else "x86_64-linux";
        pkgsLinux = import nixpkgs { system = linuxSystem; };
        texliveEnvLinux = pkgsLinux.texlive.combined.scheme-full;

        # Inkscapeラッパー: xvfb-run経由で実行してヘッドレス環境で動作させる
        inkscapeWrapped = pkgsLinux.writeShellScriptBin "inkscape" ''
          exec ${pkgsLinux.xvfb-run}/bin/xvfb-run -a ${pkgsLinux.inkscape}/bin/inkscape "$@"
        '';

        commonPackages = p: with p; [
          coreutils
          bash
          git
          gnumake
          perl
          xvfb-run
        ];

        # Dockerイメージのビルド定義
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "semi-latex-builder";
          tag = "latest";
          
          # Linux用のパッケージを使用
          contents = (commonPackages pkgsLinux) ++ [ texliveEnvLinux inkscapeWrapped ];

          config = {
            Cmd = [ "bash" ];
            WorkingDir = "/work";
            Env = [
              "SSL_CERT_FILE=${pkgsLinux.cacert}/etc/ssl/certs/ca-bundle.crt"
              "TEXMFHOME=/work/texmf"
              "TEXMFVAR=/work/.texlive-var"
              # Environment variables for headless Inkscape operation
              "HOME=/tmp"
              "DISPLAY=:99"
              "GTK_USE_PORTAL=0"
            ];
          };
        };

        # Dockerfileビルド用 (nix profile install .#latexEnv で使用)
        latexEnv = pkgs.buildEnv {
          name = "semi-latex-env";
          paths = (commonPackages pkgs) ++ [ texliveEnv pkgs.inkscape ];
        };
      in
      {
        packages = {
          default = latexEnv;
          dockerImage = dockerImage;
          latexEnv = latexEnv;
        };

        devShells.default = pkgs.mkShell {
          packages = (commonPackages pkgs) ++ [ texliveEnv pkgs.inkscape ];
          shellHook = ''
            export TEXMFHOME=$PWD/texmf
            export TEXMFVAR=$PWD/.texlive-var
          '';
        };
      }
    );
}
