# Build a Clojure library jar with the project's own tools.build `:build`
# alias. The jar ends up in $out/ and its path is recorded in
# $out/nix-support/jar-path.
{ clojure-nix-locker }:
let
  common = import ./common.nix { inherit clojure-nix-locker; };
in
{
  pkgs,
  buildCommand ? "clojure -Srepro -T:build jar",
  ...
}@args:
let
  ctx = common.mkContext (args // { inherit buildCommand; });
  inherit (ctx) lib;
in
pkgs.stdenv.mkDerivation (
  {
    pname = lib.strings.sanitizeDerivationName ctx.name;
    inherit (ctx) version passthru meta;
    src = ctx.projectSrc;

    nativeBuildInputs = ctx.baseNativeBuildInputs;

    inherit (ctx) buildPhase;
    doCheck = ctx.checkCommand != null;
    inherit (ctx) checkPhase;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/nix-support

      # jarPath may be set by a preInstall hook; don't override it
      if [ -z ''${jarPath+x} ]; then
        jarPath="$(find target -type f -name '*.jar' -print | head -n 1)"
      fi

      cp "$jarPath" $out/
      echo "$out/$(basename "$jarPath")" > $out/nix-support/jar-path

      runHook postInstall
    '';
  }
  // ctx.extraAttrs
)
