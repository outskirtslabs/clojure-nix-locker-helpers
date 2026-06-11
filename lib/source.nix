# Default source filtering for Clojure projects.
#
# Excludes the usual development droppings (caches, editor/LSP state, build
# output) so that unrelated changes don't invalidate the build.
let
  # Matched against the basename of every path, anywhere in the tree.
  defaultExcludeNames = [ ".git" ];

  # Matched against the path relative to the project root. Each entry excludes
  # the path itself and, if it is a directory, everything below it.
  defaultExcludePaths = [
    ".clj-kondo/.cache"
    ".clj-kondo/imports"
    ".clj-kondo/inline-configs"
    ".clojure-mcp"
    ".cpcache"
    ".direnv"
    ".envrc"
    ".github"
    ".lsp"
    ".nrepl-port"
    ".tmuxb_session"
    "extra"
    "node_modules"
    "result"
    "target"
  ];
in
{
  inherit defaultExcludeNames defaultExcludePaths;

  cleanCljSource =
    {
      pkgs,
      src,
      extraExcludes ? [ ],
    }:
    let
      lib = pkgs.lib;
      root = toString src;
      excludePaths = defaultExcludePaths ++ extraExcludes;
      excluded =
        rel: base:
        builtins.elem base defaultExcludeNames
        || lib.any (p: rel == p || lib.hasPrefix (p + "/") rel) excludePaths;
    in
    lib.cleanSourceWith {
      inherit src;
      filter =
        path: _type:
        let
          rel = lib.removePrefix (root + "/") (toString path);
          base = builtins.baseNameOf path;
        in
        !(excluded rel base);
    };
}
