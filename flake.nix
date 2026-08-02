{
  description = "Errm.. JWT, an implementation of Json Web Tokens for Erlang";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    errm-json = {
      url = "git+https://codeberg.org/h4rl/errm-JSON";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-uuid = {
      url = "git+https://codeberg.org/h4rl/errm-UUID";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-jwt = {
      url = "git+https://codeberg.org/h4rl/errm-JWT";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-http = {
      url = "git+https://codeberg.org/h4rl/errm-HTTP";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-env = {
      url = "git+https://codeberg.org/h4rl/errm-ENV";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-sqlite = {
      url = "git+https://codeberg.org/h4rl/errm-SQLite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-ws = {
      url = "git+https://codeberg.org/h4rl/errm-WS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    errm-json,
    errm-uuid,
    errm-jwt,
    errm-http,
    errm-env,
    errm-sqlite,
    errm-ws,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    beamPackages = pkgs.beamPackages;
    myDeps = [
      errm-json.packages.${system}.errm-json-debug
      errm-uuid.packages.${system}.errm-uuid-debug
      errm-jwt.packages.${system}.errm-jwt-debug
      errm-http.packages.${system}.errm-http-debug
      errm-env.packages.${system}.errm-env-debug
      errm-sqlite.packages.${system}.errm-sqlite-debug
      errm-ws.packages.${system}.errm-ws-debug
    ];

    errm-prod = beamPackages.buildRebar3 {
      name = "errm-a-blog";
      version = "0.1.0-prod";

      src = ./.;

      beamDeps = [
        errm-json.packages.${system}.default
        errm-uuid.packages.${system}.default
        errm-http.packages.${system}.default
        errm-env.packages.${system}.default
        errm-jwt.packages.${system}.default
        errm-sqlite.packages.${system}.default
        errm-ws.packages.${system}.default
      ];

      nativeBuildInputs = with pkgs; [
        pkg-config
      ];

      buildInputs = with pkgs; [
        brotli
        file
        just
        sqlite
      ];

      env = {
        REBAR_PROFILE = "prod";
        ERL_ROOT = "${beamPackages.erlang}/lib/erlang/";
      };
    };

    errm-debug = beamPackages.buildRebar3 {
      name = "errm-a-blog";
      version = "0.1.0-debug";

      src = ./.;

      beamDeps = [
        errm-json.packages.${system}.errm-json-debug
        errm-uuid.packages.${system}.errm-uuid-debug
        errm-http.packages.${system}.errm-http-debug
        errm-env.packages.${system}.errm-env-debug
        errm-jwt.packages.${system}.errm-jwt-debug
        errm-sqlite.packages.${system}.errm-sqlite-debug
      ];

      nativeBuildInputs = with pkgs; [
        pkg-config
      ];

      buildInputs = with pkgs; [
        brotli
        file
        just
        sqlite
      ];

      env = {
        REBAR_PROFILE = "debug";
        ERL_ROOT = "${beamPackages.erlang}/lib/erlang/";
      };
    };
  in {
    packages.${system} = {
      errm-a-blog-prod = errm-prod;
      default = errm-prod;
      errm-a-blog-debug = errm-debug;
    };

    devShells.${system} = {
      backend = pkgs.mkShell {
        name = "errm-a-blog-backend";

        buildInputs = [
          beamPackages.erlang
          beamPackages.rebar3
          pkgs.brotli
          pkgs.file
          pkgs.sqlite
          pkgs.pkg-config
          pkgs.libargon2
        ];

        packages = with pkgs; [
          erlang-language-platform
          just
          (writeShellScriptBin "switch-shell" ''
            CONTENT=$(cat ./.env-choice)
            if [[ "$CONTENT" == "backend" ]]; then
              echo "Switching to frontend"
              echo "frontend" > .env-choice
            else
              echo "Switching to backend"
              echo "backend" > .env-choice
            fi
          '')
        ];

        shellHook = ''
          mkdir -p _checkouts
          export ERL_ROOT="${beamPackages.erlang}/lib/erlang/"
          ${builtins.concatStringsSep "\n" (map (dep: ''
              for app in ${dep}/lib/erlang/lib/*; do
                ln -sfn "$app" _checkouts/$(basename "$app")
              done
            '')
            myDeps)}
        '';
      };

      frontend = pkgs.mkShell {
        name = "errm-a-blog-frontend";

        buildInputs = with pkgs; [
          deno
          biome
        ];

        packages = with pkgs; [
          svelte-language-server
          svelte-check
          typescript-language-server
          tailwindcss-language-server
          watchexec
          (writeShellScriptBin "switch-shell" ''
            CONTENT=$(cat ./.env-choice)
            if [[ "$CONTENT" == "backend" ]]; then
              echo "Switching to frontend"
              echo "frontend" > .env-choice
            else
              echo "Switching to backend"
              echo "backend" > .env-choice
            fi
          '')
        ];
      };
    };
  };
}
