{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  glib,
  gtkmm4,
  nlohmann_json,
  wrapGAppsHook4,
  makeWrapper,
  nix-update-script,
  # Wine is deliberately not bundled by default: WineGUI resolves "wine" from PATH and
  # is designed to use the system Wine, so users can point it at nix-gaming, a custom
  # build, or a per-bottle runner. Pass `wine = pkgs.wine` to pin one.
  winePkg ? null,
  # Runtime tools WineGUI shells out to for downloads, runner handling and Winetricks.
  wget,
  cabextract,
  p7zip,
  unzip,
  xz,
  util-linux,
  python3,
  zenity,
  # Upstream's .deb only lists the "non-essential" tools, because Debian guarantees
  # coreutils/sed/grep/awk/tar. WineGUI's own Winetricks bootstrap and the downloaded
  # Winetricks script call them, so on Nix they have to be provided explicitly.
  coreutils,
  gnused,
  gnugrep,
  gawk,
  gzip,
  gnutar,
  file,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "winegui";
  version = "4.5.2";

  src = fetchFromGitHub {
    owner = "winegui";
    repo = "WineGUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3N8/M9XSzHqjjHHkd58A6ZO4Nd3CAvL/XELhxU0VqsY=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    wrapGAppsHook4
    makeWrapper
    # glib-compile-schemas, used by cmake/g_settings.cmake at configure/build time
    glib
  ];

  buildInputs = [
    gtkmm4
    nlohmann_json
    # pkg-config gio-2.0 lookup in cmake/g_settings.cmake
    glib
  ];

  cmakeFlags = [
    # The git tag archive has no version.txt, so CMake would fall back to 1.0.0
    (lib.cmakeFeature "CUSTOM_PROJECT_VERSION" finalAttrs.version)
    # Updates are delivered through Nix; skip the startup update check
    (lib.cmakeBool "CHECK_FOR_UPDATE" false)
    # We compile the schema ourselves in postInstall; upstream's install-time
    # execute_process hard-codes the configure-time prefix, and upstream disables
    # this option in its own production builds too
    (lib.cmakeBool "GSETTINGS_COMPILE" false)
  ];

  postPatch = ''
    # Upstream ships a hard-coded FHS path in the desktop entry
    substituteInPlace misc/winegui.desktop \
      --replace-fail "/usr/bin/winegui" "$out/bin/winegui"
  '';

  # CMake installs the .desktop file and icons, but forgets the AppStream metadata.
  # postInstall runs from the CMake build directory, so the source path must be absolute.
  postInstall = ''
    install -Dm644 ${finalAttrs.src}/misc/org.melroy.winegui.metainfo.xml \
      $out/share/metainfo/org.melroy.winegui.metainfo.xml

    # The glib setup hook relocates share/glib-2.0/schemas to
    # share/gsettings-schemas/$name/glib-2.0/schemas during fixup but does not compile
    # it, so compile in place first; the .compiled file moves along with the directory.
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';

  # WineGUI shells out to these tools instead of linking them. Wine is left out
  # unless requested, so "live off the land" wins: whatever `wine` is first on PATH
  # (system package, home-manager, nix-gaming, a local build) is what gets used.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : "${
        lib.makeBinPath (
          lib.optionals (winePkg != null) [ winePkg ]
          ++ [
            wget
            cabextract
            p7zip
            unzip
            xz
            util-linux
            python3
            zenity
            coreutils
            gnused
            gnugrep
            gawk
            gzip
            gnutar
            file
          ]
        )
      }"
    )
  '';

  strictDeps = true;
  __structuredAttrs = true;

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "v([0-9]+\\.[0-9]+\\.[0-9]+.*)"
    ];
  };

  meta = {
    description = "User-friendly Wine prefix (bottle) manager";
    longDescription = ''
      WineGUI is a GTK4 graphical front-end for Wine that creates and manages
      Wine bottles, installs applications, downloads Wine/Proton runners and
      integrates Windows shortcuts into the desktop.
    '';
    homepage = "https://winegui.melroy.org";
    changelog = "https://github.com/winegui/WineGUI/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "winegui";
    platforms = [ "x86_64-linux" ];
    # WineGUI downloads prebuilt Wine/Proton runners at runtime; for those to run
    # use the `winegui-fhs` output instead of this bare derivation.
    maintainers = [ ];
  };
})
