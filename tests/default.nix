# Builds the fixture project with every helper. Returned as flake checks;
# `fixture-locker` is split out as a package (run it from tests/fixture to
# regenerate the fixture's deps-lock.json).
{ pkgs, cljLib }:
let
  fixtureArgs = {
    inherit pkgs;
    src = ./fixture;
    version = "0.1.0";
    prefetchAliases = [ "test" ];
    checkCommand = "clojure -Srepro -M:test";
  };

  bin = cljLib.mkCljBin (fixtureArgs // { name = "cljdemo"; });
  bbBin = cljLib.mkCljBin {
    inherit pkgs;
    name = "cljdemo-bb";
    version = "0.1.0";
    src = ./fixture-bb;
    buildCommand = "true";
  };
  libJar = cljLib.mkCljLib (fixtureArgs // { name = "cljdemo-lib"; });
  lowLevelLockfile = cljLib.mkLockfile {
    inherit pkgs;
    src = ./fixture-bb;
    lockfile = "./deps-lock.json";
  };
  lockedBabashka = lowLevelLockfile.wrapBabashka pkgs.babashka;
  jdkMin = cljLib.customJdk {
    inherit pkgs;
    cljDrv = bin;
  };
  graal = cljLib.mkGraalBin {
    inherit pkgs;
    cljDrv = bin;
  };
  app = cljLib.mkCljApp {
    inherit pkgs;
    modules = [
      {
        name = "cljdemo";
        version = "0.1.0";
        src = ./fixture;
        prefetchAliases = [ "test" ];
        checkCommand = "clojure -Srepro -M:test";
        customJdk.enable = true;
      }
    ];
  };

  cli = cljLib.mkCljCli {
    jdkDrv = jdkMin;
    java-opts = [ "-Xmx256m" ];
    extra-args = [ "--help" ];
  };
in
{
  fixture-locker = bin.locker;

  bin = bin;
  lib = libJar;
  custom-jdk = jdkMin;
  graal-bin = graal;
  app-custom-jdk = app;

  # mkCljCli is pure; just assert its shape at eval time
  cli-eval =
    assert builtins.length cli == 5;
    assert pkgs.lib.hasSuffix "/bin/java" (builtins.head cli);
    pkgs.writeText "mkCljCli-ok" (builtins.concatStringsSep " " cli);

  locker-omits-bb-prepare-without-bb-edn =
    pkgs.runCommand "locker-omits-bb-prepare-without-bb-edn" { }
      ''
        if grep -q "bb prepare" "${bin.locker}/bin/clojure-nix-locker"; then
          echo "locker for a project without bb.edn should not run bb prepare" >&2
          exit 1
        fi
        touch $out
      '';

  locker-includes-bb-prepare-with-bb-edn =
    pkgs.runCommand "locker-includes-bb-prepare-with-bb-edn" { }
      ''
        grep -q "bb prepare" "${bbBin.locker}/bin/clojure-nix-locker"
        touch $out
      '';

  wrap-babashka = pkgs.runCommand "wrap-babashka" { } ''
    test -x "${lockedBabashka}/bin/bb"
    grep -q "clojure-nix-locker.shell-env" "${lockedBabashka}/bin/bb"
    touch $out
  '';
  binaries-run = pkgs.runCommand "cljdemo-binaries-run" { } ''
    out_bin="$(${bin}/bin/cljdemo)"
    echo "mkCljBin: $out_bin"
    echo "$out_bin" | grep -q "Hello from cljdemo"
    echo "$out_bin" | grep -q "42"

    out_app="$(${app}/bin/cljdemo)"
    echo "customJdk: $out_app"
    echo "$out_app" | grep -q "Hello from cljdemo"

    out_graal="$(${graal}/bin/cljdemo)"
    echo "mkGraalBin: $out_graal"
    echo "$out_graal" | grep -q "Hello from cljdemo"

    touch $out
  '';
}
