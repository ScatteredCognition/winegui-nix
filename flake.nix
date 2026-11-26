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
          # `winePkg` is not a nixpkgs attribute, so callPackage leaves its `null`
          # default alone and no Wine is bundled. Use
          # `.override { winePkg = pkgs.wine; }` to bundle a pinned Wine instead.
          winegui = pkgs.callPackage ./package.nix { };
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
