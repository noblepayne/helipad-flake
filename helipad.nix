{ lib, pkgs, stdenv, fetchFromGitHub, rustPlatform, pkg-config, protobuf
, openssl, sqlite, ... }: rec {
  helipad = rustPlatform.buildRustPackage rec {
    pname = "helipad";
    version = "v0.1.11";
    helipadSrc = fetchFromGitHub {
      owner = "Podcastindex-org";
      repo = pname;
      rev = version;
      hash = "sha256-NtPikLo3U4zuhHrY6rZzq3UvGgZyuhwy1AEMnj+nmqA=";
    };
    src = helipadSrc;
    nativeBuildInputs = [ pkg-config protobuf ];
    buildInputs = [ openssl sqlite ] ++ lib.optional stdenv.isDarwin
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration;
    cargoHash = "sha256-VbToPgSz/rPysRLuLHV917TRatOisc2UylbteZQEVLA=";
    cargoPatches = [ ./Cargo.lock.patch ];
    meta = with lib; {
      description =
        "This is a simple lnd poller and web front-end to see and read boosts and boostagrams.";
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
      cp -r webroot $out/
    '';
  };
  helipadWrapped = pkgs.stdenv.mkDerivation {
    pname = "helipad-wrapped";
    version = helipad;
    src = helipad.outPath;
    buildInputs = [ pkgs.makeWrapper ];
    buildPhase = ''
      mkdir -p $out
      cp -r ./* $out/
      ls $out
      wrapProgram $out/bin/helipad \
        --chdir ${helipadWebroot.outPath} \
        --set HELIPAD_DATABASE_DIR /tmp/helipad_db
    '';
  };
}
