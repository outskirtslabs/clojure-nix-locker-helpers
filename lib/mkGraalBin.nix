# Compile an uberjar built by mkCljBin into a native binary with GraalVM
# native-image.
#
# Adapted from clj-nix (https://github.com/jlesquembre/clj-nix),
# Eclipse Public License 2.0.
{
  pkgs,
  cljDrv,
  name ? cljDrv.pname,
  version ? cljDrv.version,
  jarPath ? "${cljDrv.lib}/uber.jar",
  graalvm ? pkgs.graalvmPackages.graalvm-ce,
  meta ? { },

  # Options to buildGraalvmNativeImage.
  # If empty, we don't pass them; defaults from buildGraalvmNativeImage apply
  nativeBuildInputs ? [ ],
  nativeImageBuildArgs ? [ ],
  extraNativeImageBuildArgs ? [ ],
  graalvmXmx ? "",
  ...
}@attrs:
let
  lib = pkgs.lib;

  is-empty =
    element:
    if builtins.isList element then
      element == [ ]
    else if builtins.isString element then
      element == ""
    else
      false;

  # Always remove
  extra-attrs = builtins.removeAttrs attrs [
    "pkgs"
    "cljDrv"
    "name"
    "version"
    "jarPath"
    "extraNativeImageBuildArgs"
    "graalvm"
    "passthru"
  ];

  # Remove only if empty
  maybe-empty-attrs = [
    "nativeBuildInputs"
    "nativeImageBuildArgs"
    "graalvmXmx"
  ];

  extra-attrs' = lib.filterAttrs (
    k: v: !(builtins.elem k maybe-empty-attrs && is-empty v)
  ) extra-attrs;

  graal-build-time =
    let
      version = "1.0.5";
    in
    pkgs.fetchurl {
      url = "https://repo.clojars.org/com/github/clj-easy/graal-build-time/${version}/graal-build-time-${version}.jar";
      hash = "sha256-M6/U27a5n/QGuUzGmo8KphVnNa2K+LFajP5coZiFXoY=";
    };
in
pkgs.buildGraalvmNativeImage (
  {
    inherit version;
    pname = name;
    graalvmDrv = graalvm;
    meta = {
      mainProgram = name;
    }
    // meta;

    dontUnpack = true;
    src = jarPath;

    passthru =
      lib.optionalAttrs (cljDrv ? locker) { inherit (cljDrv) locker; } // (attrs.passthru or { });

    extraNativeImageBuildArgs = extraNativeImageBuildArgs ++ [
      "-classpath"
      "${graal-build-time}"
      "--features=clj_easy.graal_build_time.InitClojureClasses"
    ];
  }
  // extra-attrs'
)
