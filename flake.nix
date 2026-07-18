{
  description = "Errm.. JWT, an implementation of Json Web Tokens for Erlang";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    errm-json = {
      url = "github:h4rldev/errm-JSON";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-uuid = {
      url = "github:h4rldev/errm-UUID";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-jwt = {
      url = "github:h4rldev/errm-JWT";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-http = {
      url = "github:h4rldev/errm-HTTP";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-env = {
      url = "github:h4rldev/errm-ENV";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    errm-sqlite = {
      url = "github:h4rldev/errm-SQLite";
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
      ];

      nativeBuildInputs = with pkgs; [
        pkg-config
      ];

      buildInputs = with pkgs; [
        zstd
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
        zstd
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

    devShells.${system}.default = pkgs.mkShell {
      name = "errm-a-blog";

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
        p7zip
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
  };
}
