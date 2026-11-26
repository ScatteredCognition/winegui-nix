{
  description = "WineGUI packaged for NixOS / the Nix package manager";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          # `wine = null` is explicit: callPackage would otherwise auto-fill pkgs.wine.
          # Use `.override { wine = pkgs.wine; }` to bundle a pinned Wine instead.
          winegui = pkgs.callPackage ./package.nix { wine = null; };
        in
        {
          inherit winegui;
          winegui-fhs = pkgs.callPackage ./fhs.nix { inherit winegui; };
          default = winegui;
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
