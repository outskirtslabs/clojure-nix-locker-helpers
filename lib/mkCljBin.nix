# Build a Clojure application: an uberjar (built by the project's tools.build
# `:build` alias) plus a wrapper script at $out/bin/<name>.
#
# Outputs:
#   out: bin/<name> wrapper, nix-support/jar-path
#   lib: the uberjar under its original name, plus a stable `uber.jar`
#        symlink that customJdk and mkGraalBin consume without
#        import-from-derivation.
{ clojure-nix-locker }:
let
  common = import ./common.nix { inherit clojure-nix-locker; };
in
{
  pkgs,
  buildCommand ? "clojure -Srepro -T:build uber",
  ...
}@args:
let
  ctx = common.mkContext (args // { inherit buildCommand; });
  inherit (ctx) lib;
in
pkgs.stdenv.mkDerivation (
  {
    pname = lib.strings.sanitizeDerivationName ctx.name;
    inherit (ctx) version passthru;
    src = ctx.projectSrc;

    outputs = [
      "out"
      "lib"
    ];

    meta = {
      mainProgram = ctx.name;
    }
    // ctx.meta;

    nativeBuildInputs = ctx.baseNativeBuildInputs;

    javaOpts = lib.escapeShellArgs ctx.java-opts;

    inherit (ctx) buildPhase;
    doCheck = ctx.checkCommand != null;
    inherit (ctx) checkPhase;

    installPhase = ''
      runHook preInstall

      mkdir -p $lib $out/bin $out/nix-support

      # jarPath may be set by a preInstall hook; don't override it
      if [ -z ''${jarPath+x} ]; then
        jarPath="$(find target -type f -name '*standalone.jar' -print | head -n 1)"
        if [ -z "$jarPath" ]; then
          jarPath="$(find target -type f -name '*.jar' -print | head -n 1)"
        fi
      fi

      cp "$jarPath" $lib/
      jarName="$(basename "$jarPath")"
      ln -s "$lib/$jarName" "$lib/uber.jar"
      echo "$lib/$jarName" > $out/nix-support/jar-path

      binaryPath="$out/bin/${ctx.name}"
      substitute ${common.binaryTemplate pkgs} "$binaryPath" \
        --subst-var-by jar "$lib/$jarName" \
        --subst-var-by jdk "${ctx.jdk}" \
        --subst-var javaOpts
      chmod +x "$binaryPath"

      runHook postInstall
    '';
  }
  // ctx.extraAttrs
)
