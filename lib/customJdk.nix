# Create a minimized JDK runtime with jlink, optionally bundling an
# application jar built by mkCljBin behind a wrapper binary.
#
# Adapted from clj-nix (https://github.com/jlesquembre/clj-nix),
# Eclipse Public License 2.0.
{
  pkgs,
  cljDrv ? null,
  name ? "customJDK",
  version ? "DEV",
  # JDK to take modules from; must match the class file version of the jar
  jdkBase ? pkgs.jdk25_headless or pkgs.jdk25,
  # Path to the uberjar; defaults to the stable symlink installed by mkCljBin
  jarPath ? (if cljDrv == null then null else "${cljDrv.lib}/uber.jar"),
  # JDK modules options
  jdkModules ? null,
  extraJdkModules ? [ ],
  locales ? null,
  java-opts ? [ ],
  ...
}@attrs:
let
  lib = pkgs.lib;
  binaryTemplate = import ./binary-template.nix;

  extraAttrs = builtins.removeAttrs attrs [
    "pkgs"
    "cljDrv"
    "name"
    "version"
    "jdkBase"
    "jarPath"
    "jdkModules"
    "extraJdkModules"
    "locales"
    "java-opts"
    "passthru"
  ];

  customJdkInstallHook = pkgs.makeSetupHook {
    name = "custom-jdk-install-hook";
    propagatedBuildInputs = [
      pkgs.unzip
      pkgs.gnugrep
    ];
    substitutions = {
      binaryTemplate = binaryTemplate pkgs;
    };
  } ./custom-jdk-install-hook.sh;
in
pkgs.stdenv.mkDerivation (
  {
    name = if cljDrv == null then name else cljDrv.pname;
    version = if cljDrv == null then version else cljDrv.version;
    binaryName = if cljDrv == null then name else cljDrv.pname;

    inherit
      jarPath
      jdkModules
      extraJdkModules
      locales
      ;

    stripDebugFlags = [ "--strip-unneeded" ];
    nativeBuildInputs = [
      jdkBase
      customJdkInstallHook
    ];

    javaOpts = lib.escapeShellArgs java-opts;

    outputs =
      if cljDrv == null then
        [ "out" ]
      else
        [
          "out"
          "jdk"
        ];

    dontUnpack = true;

    passthru =
      (
        if cljDrv == null then
          { }
        else
          {
            inherit jarPath;
          }
          // lib.optionalAttrs (cljDrv ? locker) { inherit (cljDrv) locker; }
      )
      // (attrs.passthru or { });
  }
  // extraAttrs
)
