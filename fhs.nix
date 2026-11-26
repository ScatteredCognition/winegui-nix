{
  lib,
  buildFHSEnv,
  symlinkJoin,
  runCommand,
  winegui,
  wine,
}:

let
  # Desktop entry + icons for the FHS wrapper. The inner package's .desktop file
  # points at its own store binary, so it must not be reused unchanged here.
  shareTree = runCommand "winegui-fhs-share" { } ''
    mkdir -p $out/share
    cp -r ${winegui}/share/applications $out/share/
    cp -r ${winegui}/share/icons $out/share/
    cp -r ${winegui}/share/metainfo $out/share/

    substituteInPlace $out/share/applications/winegui.desktop \
      --replace-fail "${winegui}/bin/winegui" "winegui-fhs"
  '';

  fhs = buildFHSEnv {
    name = "winegui-fhs";

    multiArch = true;

    targetPkgs = pkgs: [
      winegui
      wine
      pkgs.python3
    ];

    # 32-bit libraries that downloaded Wine/Proton runners expect to find in /lib, /usr/lib
    multiPkgs =
      pkgs:
      with pkgs;
      [
        alsa-lib
        dbus
        fontconfig
        freetype
        libGL
        libpulseaudio
        libusb1
        libxkbcommon
        vulkan-loader
        SDL2
        libpthread-stubs
        libsm
        libx11
        libxcb
        libxcomposite
        libxcursor
        libxext
        libxfixes
        libxi
        libxinerama
        libxrandr
        libxrender
        libxt
        libxtst
        libxxf86vm
      ]
      ++ (with pkgs.gst_all_1; [
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly
        gst-libav
      ]);

    # winegui is itself wrapGAppsHook4-wrapped, so GTK schemas and pixbuf loaders
    # resolve correctly inside the FHS environment.
    runScript = "${winegui}/bin/winegui";
  };
in
symlinkJoin {
  name = "winegui-fhs-${winegui.version}";

  paths = [
    fhs
    shareTree
  ];

  # The binary in this output is winegui-fhs, not winegui, so mainProgram must follow
  meta = winegui.meta // {
    mainProgram = "winegui-fhs";
  };
  inherit (winegui) version;

  passthru = {
    inherit winegui;
    fhsEnv = fhs;
  };
}
