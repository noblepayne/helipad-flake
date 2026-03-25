{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.helipad;
  options.services.helipad = {
    pkgs = mkOption {
      type = types.attrs;
      description = "Package set containing helipad and helipadWebroot.";
    };
    enable =
      mkEnableOption
      "Simple lnd poller and web front-end to see and read boosts and boostagrams.";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/helipad";
      description = "Directory for helipad data and configuration.";
    };
    databaseDir = mkOption {
      type = types.path;
      default = cfg.dataDir + "/helipad_db.sqlite";
      description = "Path to the SQLite database file.";
    };
    soundDir = mkOption {
      type = types.path;
      default = cfg.dataDir + "/sounds";
      description = "Directory for boost sound files.";
    };
    listenPort = mkOption {
      type = types.port;
      default = 2112;
      description = "Port to listen on.";
    };
    password = mkOption {
      type = types.str;
      default = "";
      description = "Password for the web frontend.";
    };
    macaroon = mkOption {
      type = types.path;
      default = "/var/lib/lnd/data/chain/bitcoin/mainnet/admin.macaroon";
      description = "Path to LND admin.macaroon.";
    };
    cert = mkOption {
      type = types.path;
      default = "/var/lib/lnd/tls.cert";
      description = "Path to LND tls.cert.";
    };
    lndUrl = mkOption {
      type = types.str;
      default = "https://127.0.0.1:10009";
      description = "URL of the LND gRPC API.";
    };
    user = mkOption {
      type = types.str;
      default = "helipad";
      description = "User to run the service as.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "Group to run the service as.";
    };
    extraHardening = mkOption {
      type = types.bool;
      default = true;
      description = "Enable extra systemd hardening options.";
    };
  };

  # Configuration file generation
  # Helipad uses a simple key="value" format (or sometimes just key=value)
  helipadConfig = pkgs.writeText "helipad.conf" ''
    database_dir="${cfg.databaseDir}"
    sound_dir="${cfg.soundDir}"
    listen_port=${builtins.toString cfg.listenPort}
    macaroon="${cfg.macaroon}"
    lnd_url="${cfg.lndUrl}"
    cert="${cfg.cert}"
    ${optionalString (cfg.password != "") "password=\"${cfg.password}\""}
  '';
in {
  inherit options;
  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = {};

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.soundDir}' 0770 ${cfg.user} ${cfg.group} - -"
      "L '${cfg.dataDir}/helipad.conf' - - - - ${helipadConfig}"
      "L '${cfg.dataDir}/webroot' - - - - ${cfg.pkgs.helipadWebroot}"
    ];

    systemd.services.helipad = {
      description = "Helipad - LND Poller and Web Frontend";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "lnd.service"];
      environment = {
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      };
      serviceConfig =
        {
          User = cfg.user;
          Group = cfg.group;
          Restart = "on-failure";
          RestartSec = "10s";
          WorkingDirectory = cfg.dataDir;
          ExecStart = "${cfg.pkgs.helipad}/bin/helipad";

          # Permissions
          ReadWritePaths = [cfg.dataDir];
          ReadOnlyPaths = [cfg.pkgs.helipadWebroot "/etc" "/var"];

          # Hardening
        }
        // optionalAttrs cfg.extraHardening {
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          MemoryDenyWriteExecute = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          SystemCallArchitectures = "native";
          # Note: helipad needs network for LND and web frontend
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        };
    };
  };
}
