# winegui-nix

Nix flake for [WineGUI](https://github.com/winegui/WineGUI) — the GTK4 graphical Wine
prefix (bottle) manager.

WineGUI is not packaged in nixpkgs, so this flake builds it from the upstream git tag and
wraps it with the runtime tools it shells out to (`wget`, `cabextract`, `7z`, `unzip`, `xz`,
`taskset`, `python3`, `zenity`, plus the coreutils/sed/grep/awk set upstream treats as
"essential"). **Wine itself is not bundled** — see [Which Wine is used](#which-wine-is-used).

Current upstream version: **4.5.2**

## Two outputs, pick one

| Output | What it is | When to use |
|---|---|---|
| `winegui` (default) | Plain derivation, ~980 MiB closure, uses the `wine` on your PATH | You manage bottles with your system / custom Wine |
| `winegui-fhs` | `buildFHSEnv` wrapper (multiArch), Bottles-style, ships its own Wine | You want WineGUI's **download & switch Wine runner** feature (Kron4ek, GE-Proton/umu-run) |

Prebuilt Wine/Proton runners are ordinary Linux binaries that expect `/usr/lib` and friends —
they do not run in a normal Nix store environment. That is the only reason the FHS variant
exists. Both variants share `~/.local/share/winegui`, so bottles created in one work in the other.

## Which Wine is used

By default this package **does not bundle Wine**. WineGUI resolves `wine`, `wine64` and
`wineserver` from `PATH` at runtime, so whatever comes first wins:

```nix
environment.systemPackages = [ pkgs.wine ];            # nixpkgs
# or a custom/bleeding-edge build:
# environment.systemPackages = [ inputs.nix-gaming.packages.${system}.wine-tkg-staging-fsync-git ];
# home.packages = [ pkgs.wineWow64Packages.staging ];
```

A locally compiled Wine works too as long as its `bin` directory is on `PATH`. You can also
set a per-bottle **custom Wine binary path** in WineGUI's Edit window, which overrides the
system Wine for that bottle only — handle for something like a patched Proton build that you
don't want on your global `PATH`.

If no Wine is found, WineGUI reports *"Could not find wine binary. Please install Wine on your
machine and try again."* WineGUI requires Wine 9 or newer.

To pin a specific Wine into the wrapper anyway (at the cost of ~1.5 GiB of closure and
shadowing the user's Wine):

```nix
winegui-nix.packages.x86_64-linux.winegui.override { wine = pkgs.wineWow64Packages.staging; }
```

## Winetricks

WineGUI **never uses a Winetricks from `PATH`**. It manages its own copy:

1. On first use it downloads `https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks`
   with `wget` into `$XDG_DATA_HOME/winegui/winetricks` and `chmod +x`es it
   (`helper.cc: install_or_update_winetricks`).
2. Later it refreshes that copy via `winetricks --self-update`, falling back to the old copy
   with a warning if the update fails (`helper.cc: self_update_winetricks`).
3. It reports the version by running `winetricks --version` (an 8-digit `YYYYMMDD` date), and
   runs it against the bottle's selected runner — through `umu-run winetricks` for GE-Proton,
   otherwise with `WINE`/`WINELOADER`/`WINESERVER` pointing at that bottle's Wine.

Consequences on NixOS:

- Adding `pkgs.winetricks` to your profile changes nothing for WineGUI. That is why it is not
  in the wrapped `PATH`.
- The **downloaded** copy is an unpatched upstream shell script, so it needs its own tools:
  `wget`, `cabextract`, `7z`, `unzip`, `xz`, `zenity`, `tar`, `gzip`, `sed`, `grep`, `awk`,
  `coreutils`, `file`. All of those are wrapped into `PATH`, which is why the app works even
  when launched with a minimal environment.
- Because the script lives in your home directory it is not reproducible or patched by Nix;
  that is upstream's design, not a packaging choice. It also means Winetricks needs network
  access on first run.

## Install

Run without installing:

```bash
nix run github:ScatteredCognition/winegui-nix            # lean
nix run github:ScatteredCognition/winegui-nix#winegui-fhs # FHS (runner downloads)
```

Install into a profile:

```bash
nix profile add github:ScatteredCognition/winegui-nix#winegui
```

Use it in a NixOS / Home Manager configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    winegui-nix.url = "github:ScatteredCognition/winegui-nix";
    winegui-nix.inputs.nixpkgs.follows = "nixpkgs"; # share one nixpkgs
  };

  outputs = { nixpkgs, winegui-nix, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        {
          environment.systemPackages = [
            winegui-nix.packages.x86_64-linux.winegui
          ];
        }
      ];
    };
  };
}
```

If you use `pkgs.system` shorthand, `winegui-nix.packages.${pkgs.system}.winegui-fhs` works too.

## NixOS prerequisites

```nix
{
  hardware.graphics.enable = true;
  # Needed for any 32-bit Windows application / win32 bottle.
  # Still recommended for the lean output; mandatory in practice for winegui-fhs.
  hardware.graphics.enable32Bit = true;
}
```

Steam is *not* required — WineGUI's umu/GE-Proton launcher is self-managed.

`programs.dconf.enable = true` is recommended: WineGUI stores window state through GSettings
(`org.melroy.winegui`), and without the dconf D-Bus service GLib falls back to the in-memory
backend, so window geometry won't survive a restart. Most desktop environments enable this
already; a bare NixOS config does not.

## Notes / known limitations

- **Startup update check is disabled** (`-DCHECK_FOR_UPDATE=OFF`). Updates come from this
  flake; refresh with `nix flake update` or update the input.
- **Wine is not bundled**, so the lean closure is ~980 MiB instead of ~2.6 GiB, and your own
  Wine (nix-gaming, a local build, per-bottle runner) is never shadowed by a packaged one.
- AppStream metadata is installed manually (`share/metainfo/org.melroy.winegui.metainfo.xml`)
  because upstream's CMake does not install it. Its `<id>` differs from the desktop file name;
  that is upstream's choice, not a packaging bug.
- The desktop entry's `Exec=` is rewritten from `/usr/bin/winegui` to the store path, and the
  FHS output points at `winegui-fhs`.
- `python3` is wrapped in for the umu/GE-Proton launcher; it is the only "maybe unused"
  runtime dependency left (~150 MiB of closure).

## Repo layout

```
flake.nix   # packages.default, packages.winegui, packages.winegui-fhs
package.nix # lean derivation (candidate for upstreaming to nixpkgs)
fhs.nix     # buildFHSEnv variant
```

## Updating

`nix-update` drives the version bump (the regex is needed because the tag is prefixed with `v`):

```bash
nix run nixpkgs#nix-update -- flake winegui --version-regex 'v([0-9]+\.[0-9]+\.[0-9]+.*)'
```

The `update` workflow does this weekly and opens a PR.

## Upstreaming to nixpkgs

`package.nix` is intentionally written to be submittable as
`pkgs/by-name/wi/winegui/package.nix`:

- keep `CUSTOM_PROJECT_VERSION`, `CHECK_FOR_UPDATE=false`, `GSETTINGS_COMPILE=false`;
- `passthru.updateScript = nix-update-script { }` (no arguments inside nixpkgs);
- set `meta.maintainers` to your nixpkgs handle;
- nixpkgs convention would auto-fill `wine` via `callPackage`. Either accept a bundled Wine
  there (`wine` default from pkgs, like `bottles` does) or keep `wine = null` and say why in
  the commit message — reviewers will ask either way;
- if a newer compiler trips upstream's hard-coded `-Werror`, prefer patching the offending
  warnings rather than adding `-Wno-error`.
