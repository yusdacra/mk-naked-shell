{lib, flake-parts-lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    perSystem =
      flake-parts-lib.mkPerSystemOptions
      ({...}: {
        options = {
          mk-naked-shell.lib.mkNakedShell = l.mkOption {
            type = t.functionTo t.package;
          };
        };
      });
  };
  config = {
    perSystem = {pkgs, ...}: {
      mk-naked-shell.lib.mkNakedShell =
        l.mkDefaultOption (pkgs.callPackage ./default.nix {});
    };
  };
}
