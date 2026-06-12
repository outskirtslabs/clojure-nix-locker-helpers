{
  description = "clj-nix style builders (mkCljBin, mkCljLib, mkCljApp, customJdk, mkGraalBin, mkCljCli) powered by clojure-nix-locker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    clojure-nix-locker.url = "github:bevuta/clojure-nix-locker";
    clojure-nix-locker.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      clojure-nix-locker,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      cljLib = import ./lib { inherit clojure-nix-locker; };
      standaloneLocker =
        pkgs: (import "${clojure-nix-locker}/default.nix" { inherit pkgs; }).standaloneLocker;
    in
    {
      lib = cljLib;

      overlays.default = final: prev: {
        deps-lock = standaloneLocker final;
      };

      packages = eachSystem (pkgs: rec {
        deps-lock = standaloneLocker pkgs;
        default = deps-lock;
        fixture-locker = (import ./tests { inherit pkgs cljLib; }).fixture-locker;
      });

      checks = eachSystem (
        pkgs: builtins.removeAttrs (import ./tests { inherit pkgs cljLib; }) [ "fixture-locker" ]
      );

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.jdk25
            (pkgs.clojure.override { jdk = pkgs.jdk25; })
            (standaloneLocker pkgs)
            pkgs.nixfmt-rfc-style
          ];
        };
      });

      formatter = eachSystem (pkgs: pkgs.nixfmt-rfc-style);
    };
}
