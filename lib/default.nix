# Public API of clojure-nix-locker-helpers.
#
# All builders take `pkgs` explicitly so they can be used from any flake
# without an overlay.
{ clojure-nix-locker }:
let
  common = import ./common.nix { inherit clojure-nix-locker; };
  source = import ./source.nix;
  lockerLib = import ./locker.nix { inherit clojure-nix-locker; };
in
{
  inherit (common) defaultMavenRepos;

  # gitRev self: a stable revision string for the current flake evaluation
  gitRev = common.gitRevOf;

  inherit (source) cleanCljSource;

  # Low-level escape hatches (thin wrappers over clojure-nix-locker)
  inherit (lockerLib) mkLockerPkgs mkLockfile mkLocker;

  # High-level builders
  mkCljLib = import ./mkCljLib.nix { inherit clojure-nix-locker; };
  mkCljBin = import ./mkCljBin.nix { inherit clojure-nix-locker; };
  mkCljApp = import ./mkCljApp.nix { inherit clojure-nix-locker; };
  customJdk = import ./customJdk.nix;
  mkGraalBin = import ./mkGraalBin.nix;
  mkCljCli = import ./mkCljCli.nix;
}
