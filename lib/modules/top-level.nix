# Module options for mkCljApp.
#
# Adapted from clj-nix (https://github.com/jlesquembre/clj-nix),
# Eclipse Public License 2.0.
{
  lib,
  pkgs,
  ...
}:
let
  types = lib.types;
in
{
  options = {

    jdk = lib.mkOption {
      type = types.package;
      default = pkgs.jdk25;
      defaultText = lib.literalExpression "pkgs.jdk25";
      description = "JDK used to build and run the application.";
    };

    src = lib.mkOption {
      type = types.path;
      description = "Project source code.";
      example = lib.literalExpression "./.";
    };

    name = lib.mkOption {
      type = types.str;
      description = "Name of the project; also the name of the wrapper binary.";
      example = "my-app";
    };

    version = lib.mkOption {
      default = "DEV";
      type = types.str;
      description = "Derivation and project version.";
    };

    cleanSrc = lib.mkOption {
      default = true;
      type = types.bool;
      description = "Apply the default Clojure source filter to src.";
    };

    extraSrcExcludes = lib.mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = "Extra root-relative paths excluded from the source.";
    };

    lockfile = lib.mkOption {
      default = "deps-lock.json";
      type = types.str;
      description = "Path of the lockfile, relative to the project root.";
    };

    mavenRepos = lib.mkOption {
      default = [
        "https://repo1.maven.org/maven2/"
        "https://repo.clojars.org/"
      ];
      type = types.listOf types.str;
      description = "Maven repositories the locked dependencies are fetched from.";
    };

    extraPrepInputs = lib.mkOption {
      default = [ pkgs.git ];
      defaultText = lib.literalExpression "[ pkgs.git ]";
      type = types.listOf types.package;
      description = "Extra inputs for the dependency prep phase of the locker.";
    };

    prepAliases = lib.mkOption {
      default = [ ];
      type = types.listOf types.str;
      example = [
        "dev"
        "test"
      ];
      description = "Aliases passed to `clojure -X:deps prep` before building and locking.";
    };

    prefetchAliases = lib.mkOption {
      default = [ ];
      type = types.listOf types.str;
      example = [ "dev:test" ];
      description = "Aliases prefetched with `clojure -P -M:<alias>` while locking.";
    };

    checkCommand = lib.mkOption {
      default = null;
      type = types.nullOr types.str;
      example = "clojure -Srepro -M:dev:kaocha";
      description = "Command run in the checkPhase; checks are skipped when null.";
    };

    buildCommand = lib.mkOption {
      default = null;
      type = types.nullOr types.str;
      description = "Command to build the uberjar. Defaults to `clojure -Srepro -T:build uber`.";
    };

    lockCommand = lib.mkOption {
      default = null;
      type = types.nullOr types.str;
      description = "Full override of the derived locker command.";
    };

    gitRev = lib.mkOption {
      default = null;
      type = types.nullOr types.str;
      description = "Exported as GIT_REV during the build, e.g. from `gitRev self`.";
    };

    java-opts = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of Java options to include in the application wrapper.";
    };

    nativeBuildInputs = lib.mkOption {
      default = [ ];
      type = types.listOf types.package;
      description = "Extra build-time dependencies.";
    };

    ###
    # Options for customJdk
    ###

    customJdk = lib.mkOption {
      default = { };
      type = types.submodule {
        options = {
          enable = lib.mkOption {
            default = false;
            type = types.bool;
            description = "Creates a custom JDK runtime with `jlink`.";
          };

          jdkModules = lib.mkOption {
            default = null;
            type = types.nullOr types.str;
            description = ''
              Option passed to `jlink --add-modules`.
              If `null`, `jdeps` will be used to analyze the uberjar.
            '';
          };

          extraJdkModules = lib.mkOption {
            default = [ ];
            type = types.listOf types.str;
            description = "Extra JDK modules appended to `jdkModules`.";
          };

          locales = lib.mkOption {
            default = null;
            type = types.nullOr types.str;
            description = "Option passed to `jlink --include-locales`.";
          };
        };
      };
    };

    ###
    # Options for nativeImage
    ###

    nativeImage = lib.mkOption {
      default = { };
      type = types.submodule {
        options = {
          enable = lib.mkOption {
            default = false;
            type = types.bool;
            description = "Generates a binary with GraalVM.";
          };

          graalvm = lib.mkOption {
            default = pkgs.graalvmPackages.graalvm-ce;
            defaultText = lib.literalExpression "pkgs.graalvmPackages.graalvm-ce";
            type = types.package;
            description = "GraalVM used at build time.";
          };

          extraNativeImageBuildArgs = lib.mkOption {
            default = [ ];
            type = types.listOf types.str;
            description = "Extra arguments to be passed to the native-image command.";
          };

          graalvmXmx = lib.mkOption {
            default = "-J-Xmx6g";
            type = types.str;
            description = "XMX size of GraalVM during build.";
          };

          static = lib.mkOption {
            default = false;
            type = types.bool;
            description = "Build a static binary using musl libc.";
          };
        };
      };
    };
  };
}
