{ config, lib, pkgs, ... }:

with lib;
let
  options.services.helipad = {
    pkgs = mkOption {
      type = types.attrs;
    };
    enable = mkEnableOption
      "Simple lnd poller and web front-end to see and read boosts and boostagrams.";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/helipad";
      # TODO: descriptions.
    };
    databaseDir = mkOption {
      type = types.path;
      default = cfg.dataDir + "/helipad_db.sqlite";
    };
    listenPort = mkOption {
      type = types.port;
      default = 2112;
    };
    password = mkOption {
      type = types.str;
      default = "";
    };
    macaroon = mkOption {
      type = types.path;
      default = "/var/lib/lnd/data/chain/bitcoin/mainnet/admin.macaroon";
    };
    cert = mkOption {
      type = types.path;
      default = "/var/lib/lnd/tls.cert";
    };
    lndUrl = mkOption {
      type = types.str;
      default = "https://127.0.0.1:10009";
    };
    user = mkOption {
      type = types.str;
      default = "helipad";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
    };
  };

  cfg = config.services.helipad;
  # TODO: password
  helipadConfig = builtins.toFile "config" ''
    database_dir="${cfg.databaseDir}"
    listen_port=${builtins.toString cfg.listenPort}
    macaroon="${cfg.macaroon}"
    cert="${cfg.cert}"
  '';
in {
  inherit options;
  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      # TODO: extraGroups
    };
    users.groups.${cfg.group} = {};
    systemd.tmpfiles.rules = [
      # Create our dataDir.
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      # Link our config.
      "L '${cfg.dataDir}/helipad.conf' - - - - ${helipadConfig}"
      # Link webroot.
      "L '${cfg.dataDir}/webroot' - - - - ${cfg.pkgs.helipadWebroot}"
    ];
    environment.systemPackages = [ cfg.pkgs.helipad ];
  };
}
