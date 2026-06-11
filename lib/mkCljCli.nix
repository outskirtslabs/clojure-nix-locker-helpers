# Build a command (as a list of strings) to run a jar produced by customJdk,
# e.g. for a systemd ExecStart or NixOS module.
#
# Adapted from clj-nix (https://github.com/jlesquembre/clj-nix),
# Eclipse Public License 2.0.
let
  formatArg =
    x:
    if x == null then
      [ ]
    else if (builtins.isList x) then
      x
    else
      [ x ];
in
{
  jdkDrv,
  java-opts ? [ ],
  extra-args ? [ ],
}:
builtins.filter (s: builtins.stringLength s != 0) (
  [
    "${jdkDrv.jdk}/bin/java"
  ]
  ++ (formatArg java-opts)
  ++ [
    "-jar"
    "${jdkDrv.jarPath}"
  ]
  ++ (formatArg extra-args)
)
