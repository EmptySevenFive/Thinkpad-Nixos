{ config, pkgs, ... }:

let
  home-manager = fetchTarball
    "https://github.com/nix-community/home-manager/archive/release-22.11.tar.gz";
  emacs-overlay = fetchTarball
    "https://github.com/nix-community/emacs-overlay/archive/4a14e8f79e91636cdfc4cecc3f12cdc4cfe57a60.tar.gz";
in
{
  # nix = import ./nix.nix;

  system.stateVersion = "22.11";

  imports = [ ./hardware-configuration.nix "${home-manager}/nixos" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "will-lap";

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_AU.UTF-8";

  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
  services.gnome.core-utilities.enable = false;

  services.openssh.enable = true;

  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.student = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    passwordFile = "/etc/passwordFile-will";
  };

  fonts = {
    fonts = with pkgs;
      [ (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];
    fontconfig = {
      defaultFonts = { monospace = [ "JetBrainsMonoNL Nerd Font Mono" ]; };
      localConf = ''
        <selectfont>
          <rejectfont>
            <pattern>
              <patelt name="family">
                <string>TeX Gyre Heros</string>
              </patelt>
            </pattern>
          </rejectfont>
        </selectfont>
      '';
    };
  };

  home-manager.users.student = { pkgs, lib, ... }: {
    home.stateVersion = "22.11";

    nixpkgs.overlays = [ (import emacs-overlay) ];

    home.packages = with pkgs; [
      # desktop
      gnomeExtensions.night-theme-switcher
      gnomeExtensions.emoji-selector
      gimp
      emacs-all-the-icons-fonts

      (pkgs.emacsWithPackagesFromUsePackage {
        config = ./dot/emacs.el;
        defaultInitFile = true;
        alwaysEnsure = true;
        package = pkgs.emacsPgtk;
      })

      # cli
      git
      file
      tree
      cloc
      ripgrep
      wl-clipboard
      fd
      htop
      ncdu
      ffmpeg
      mpv
      youtube-dl
      unzip
      qmk
      heroku
      rclone
      (aspellWithDicts (dicts: with dicts; [ en en-computers en-science ]))
      (texlive.combine {
        inherit (texlive) scheme-basic
          wrapfig amsmath ulem hyperref capt-of;
      })

      (writeShellScriptBin "audio-to-video"
        (builtins.readFile ./bin/audio-to-video.sh))
      (writeShellScriptBin "new-ssh-key"
        (builtins.readFile ./bin/new-ssh-key.sh))
      (writeShellScriptBin "track-willos"
        (builtins.readFile ./bin/track-willos.sh))
      (writeShellScriptBin "ydl" (builtins.readFile ./bin/ydl.sh))

      # nix
      rnix-lsp
      nixfmt

      # bash
      nodePackages.bash-language-server

      # c
      gcc
      clang-tools

      # web
      nodejs
      nodePackages.vscode-langservers-extracted
      nodePackages.typescript
      (symlinkJoin {
        name = "typescript-language-server";
        paths = [ nodePackages.typescript-language-server ];
        buildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/typescript-language-server \
            --add-flags --tsserver-path=${nodePackages.typescript}/lib/node_modules/typescript/lib/
        '';
      })

      # python
      python310
      python310Packages.python-lsp-server

      # haskell
      ghc
      cabal-install
      haskell-language-server
      haskellPackages.hoogle
      ormolu

      # clojure
      clojure
      leiningen
      clojure-lsp

      # rust
      rustc
      cargo
      rustfmt
      rust-analyzer

      # yaml
      nodePackages.yaml-language-server

      # toml
      taplo
    ];

    programs.bash = {
      enable = true;
      historySize = -1;
      historyFileSize = -1;
      historyControl = [ "ignoredups" ];
      shellAliases = {
        diff = "git diff --no-index";
        grep = "grep --color=auto";
        ncdu = "ncdu --color off";
      };
      initExtra = ''
        stty -ixon
        set enable-bracketed-paste on
      '';
    };

    programs.firefox = {
      enable = true;
      package = pkgs.firefox-wayland;
      profiles.will = { extraConfig = builtins.readFile ./dot/user.js; };
    };

    home.file = {
      gitconfig = {
        source = ./dot/gitconfig;
        target = ".config/git/config";
      };
      ghci = {
        source = ./dot/ghci;
        target = ".ghci";
      };
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "image/png" = [ "firefox.desktop" ];
        "application/pdf" = [ "firefox.desktop" ];
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        clock-format = "12h";
        clock-show-weekday = true;
        enable-animations = false;
        text-scaling-factor = 1.25;
        enable-hot-corners = false;
      };
      "org/gnome/system/location" = {
        enabled = true;
      };
      "org/gnome/desktop/input-sources" = {
        xkb-options = [ "compose:rwin" ];
      };
      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        tap-and-drag = false;
      };
      "org/gnome/desktop/background" = {
        picture-uri =
          "file:///run/current-system/sw/share/backgrounds/gnome/dune-l.svg";
        picture-uri-dark =
          "file:///run/current-system/sw/share/backgrounds/gnome/dune-d.svg";
      };
      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 0;
      };
      "org/gnome/shell" = {
        enabled-extensions = [
          "nightthemeswitcher@romainvigier.fr"
          "emoji-selector@maestroschan.fr"
        ];
      };
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
      };
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
      };
      "org/gtk/settings/file-chooser" = { clock-format = "12h"; };

      "org/gnome/shell/extensions/nightthemeswitcher/gtk-variants" = {
        enabled = true;
      };
      "org/gnome/shell/extensions/nightthemeswitcher/time" = {
        always-enable-ondemand = true;
        nightlight-follow-disable = true;
        manual-schedule = false;
      };
    };
  };
}
