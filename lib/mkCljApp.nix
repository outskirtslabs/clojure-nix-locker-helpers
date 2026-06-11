# Module-based entry point: build a Clojure application and optionally wrap
# it in a jlink-minimized JDK or compile it to a native binary with GraalVM.
#
# Adapted from clj-nix (https://github.com/jlesquembre/clj-nix),
# Eclipse Public License 2.0.
{ clojure-nix-locker }:
let
  mkCljBin = import ./mkCljBin.nix { inherit clojure-nix-locker; };
  customJdk = import ./customJdk.nix;
  mkGraalBin = import ./mkGraalBin.nix;
in
{ pkgs, modules }:
let
  lib = pkgs.lib;

  evaled = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [ ./modules/top-level.nix ] ++ modules;
  };

  cfg = evaled.config;
in

assert (
  lib.assertMsg (
    cfg.customJdk.enable -> !cfg.nativeImage.enable
  ) "customJdk and nativeImage are incompatible, you can enable only one"
);

let
  cljDrv = mkCljBin (
    {
      inherit pkgs;
      inherit (cfg)
        jdk
        src
        name
        version
        cleanSrc
        extraSrcExcludes
        lockfile
        mavenRepos
        extraPrepInputs
        prepAliases
        prefetchAliases
        checkCommand
        lockCommand
        gitRev
        java-opts
        nativeBuildInputs
        ;
    }
    // lib.optionalAttrs (cfg.buildCommand != null) {
      inherit (cfg) buildCommand;
    }
  );
in

if cfg.customJdk.enable then
  customJdk {
    inherit pkgs cljDrv;
    jdkBase = cfg.jdk;
    java-opts = cfg.java-opts;
    inherit (cfg.customJdk) jdkModules extraJdkModules locales;
  }

else if cfg.nativeImage.enable then
  mkGraalBin {
    inherit pkgs cljDrv;

    graalvm =
      if cfg.nativeImage.static then pkgs.graalvmPackages.graalvm-ce-musl else cfg.nativeImage.graalvm;

    extraNativeImageBuildArgs =
      cfg.nativeImage.extraNativeImageBuildArgs
      ++ (lib.optionals cfg.nativeImage.static [
        "--static"
        "--libc=musl"
      ]);
    inherit (cfg.nativeImage) graalvmXmx;
  }
else
  cljDrv
