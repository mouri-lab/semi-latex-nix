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

        # Inkscape wrapper for headless Docker environments: runs via xvfb-run
        # Note: xvfb-run and its dependencies are automatically included via Nix closure
        inkscapeWrapped = pkgsLinux.writeShellScriptBin "inkscape" ''
          # Ensure HOME directory exists for GTK, with fallback
          HOME=''${HOME:-/tmp/inkscape-home}
          mkdir -p "$HOME"
          # Run Inkscape with virtual X server
          # -a: automatically pick a free display number
          # -e: propagate exit code from inkscape
          # -s: create screen with given parameters (size and depth)
          exec ${pkgsLinux.xvfb-run}/bin/xvfb-run -a -e -s "-screen 0 1024x768x24" ${pkgsLinux.inkscape}/bin/inkscape "$@"
        '';

        commonPackages = p: with p; [
          bash
          git
          gnumake
          perl
          glibcLocales  # Required for UTF-8 locale support
        ];

        commonPackagesDocker = p: with p; [
          busybox  # Provides grep, ls, and other basic utilities
          bash
          git
          gnumake
          perl
          glibcLocales  # Required for UTF-8 locale support
        ];

        commonPackagesDev = p: with p; [
          coreutils  # Full coreutils for development
          bash
          git
          gnumake
          perl
          rsync
          fswatch  # File watcher for watch mode
          # Japanese fonts for Inkscape
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
        ];

        # Fontconfig configuration to map Helvetica to Japanese font
        fontsConf = pkgs.writeText "fonts.conf" ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
          <fontconfig>
            <dir>${pkgs.noto-fonts-cjk-sans}/share/fonts</dir>
            <dir>${pkgs.noto-fonts-cjk-serif}/share/fonts</dir>
            <match target="pattern">
              <test qual="any" name="family">
                <string>Helvetica</string>
              </test>
              <edit name="family" mode="prepend" binding="strong">
                <string>Noto Sans CJK JP</string>
              </edit>
            </match>
          </fontconfig>
        '';

        # Dockerイメージのビルド定義
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "semi-latex-builder";
          tag = "latest";

          # Linux用のパッケージを使用
          contents = (commonPackagesDocker pkgsLinux) ++ [ texliveEnvLinux inkscapeWrapped ];

          # Create /tmp directory with proper permissions
          extraCommands = ''
            mkdir -p tmp
            chmod 1777 tmp
          '';

          config = {
            Cmd = [ "bash" ];
            WorkingDir = "/work";
            Env = [
              "SSL_CERT_FILE=${pkgsLinux.cacert}/etc/ssl/certs/ca-bundle.crt"
              "TEXMFHOME=/work/texmf"
              "TEXMFVAR=/work/.texlive-var"
              # Environment variables for headless Inkscape operation
              "HOME=/tmp/inkscape-home"
              "TMPDIR=/tmp"
              "TMP=/tmp"
              "TEMP=/tmp"
              "GTK_USE_PORTAL=0"
              "GDK_BACKEND=x11"
              # Prevent fontconfig warnings
              "FONTCONFIG_PATH=${pkgsLinux.fontconfig.out}/etc/fonts"
              # Set locale for proper UTF-8 handling
              "LOCALE_ARCHIVE=${pkgsLinux.glibcLocales}/lib/locale/locale-archive"
              "LANG=C.UTF-8"
              "LC_ALL=C.UTF-8"
              "SEMI_LATEX_ENV=1"
            ];
          };
        };

        # Dockerfileビルド用 (nix profile install .#latexEnv で使用)
        latexEnv = pkgs.buildEnv {
          name = "semi-latex-env";
          paths = (commonPackagesDev pkgs) ++ [ texliveEnv pkgs.inkscape ];
        };
      in
      {
        packages = {
          default = latexEnv;
          dockerImage = dockerImage;
          latexEnv = latexEnv;
        };

        devShells.default = pkgs.mkShell {
          packages = (commonPackagesDev pkgs) ++ [ texliveEnv pkgs.inkscape ];
          shellHook = ''
            export TEXMFHOME=$PWD/texmf
            export TEXMFVAR=$PWD/.texlive-var
            export SEMI_LATEX_ENV=1
            export FONTCONFIG_FILE=${fontsConf}

            # Set Japanese font to IPAex (compatible with mouri-lab/semi-latex Docker image)
            # Check if font map needs to be regenerated for this TEXMFVAR
            _KANJIX_MAP="$TEXMFVAR/fonts/map/dvipdfmx/updmap/kanjix.map"
            if [ ! -f "$_KANJIX_MAP" ]; then
              # Font map doesn't exist in TEXMFVAR, need to set up
              if ! kanji-config-updmap status 2>/dev/null | grep -q "CURRENT family for ja: ipaex"; then
                echo "Setting Japanese font to IPAex..."
                kanji-config-updmap-user ipaex >/dev/null 2>&1 || true
              else
                # Already configured but map not in TEXMFVAR, regenerate
                echo "Regenerating font maps for TEXMFVAR..."
                updmap-user >/dev/null 2>&1 || true
              fi
            fi
          '';
        };
      }
    );
}
