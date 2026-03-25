{
  lib,
  pkgs,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  protobuf,
  openssl,
  sqlite,
  ...
}: rec {
  helipad = rustPlatform.buildRustPackage rec {
    pname = "helipad";
    version = "0.2.2";
    helipadSrc = fetchFromGitHub {
      owner = "Podcastindex-org";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-PaAna0QxePU84Wy30alJgF1xQvq5K5bSlDdJaSgzPFs=";
    };
    src = helipadSrc;
    nativeBuildInputs = [pkg-config protobuf];
    buildInputs =
      [openssl sqlite]
      ++ lib.optional stdenv.isDarwin
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration;
    cargoPatches = [./Cargo.lock.patch];
    cargoHash = "sha256-gcAm1Xj81KzbxUIQDmXQ/Rqj+H4OeKkV0bn6SfHQa88=";
    meta = with lib; {
      description = "This is a simple lnd poller and web front-end to see and read boosts and boostagrams.";
      homepage = "https://github.com/Podcastindex-org/helipad";
      license = licenses.mit;
      # maintainers = [];
    };
  };
  helipadWebroot = pkgs.stdenv.mkDerivation {
    pname = "helipad-webroot";
    version = helipad.version;
    src = helipad.src;
    buildPhase = ''
      cp -r webroot $out
    '';
  };
  # helipadWrapped = pkgs.stdenv.mkDerivation {
  #   pname = "helipad-wrapped";
  #   version = helipad;
  #   src = helipad.outPath;
  #   buildInputs = [ pkgs.makeWrapper ];
  #   buildPhase = ''
  #     mkdir -p $out
  #     cp -r ./* $out/
  #     ls $out
  #     wrapProgram $out/bin/helipad \
  #       --chdir ${helipadWebroot.outPath} \
  #       --set HELIPAD_DATABASE_DIR /tmp/helipad_db
  #   '';
  # };
}
