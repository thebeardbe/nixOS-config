# LAN party station: the five services that have to be up before the kids arrive
# and after every reboot. Each unit runs the launcher script from the lanparty
# repository, which already refuses to start on a busy port, waits for its own
# readiness and stops its children on TERM, so there is no second copy of the
# lifecycle logic here.
#
# Grouped under `party.target` so the operator has one command per action:
#   systemctl start party / stop party / status
# `scripts/party-lan.sh` in the repository does the same by hand, for a restart
# without going through systemd.
{ config, lib, pkgs, ... }:

let
  user = "thebeardbe";
  home = "/home/${user}";
  repo = "${home}/Projects/lan-scoreboard";

  # systemd gives a service a bare PATH, which on NixOS is nearly empty. The
  # launcher scripts call python3, nix, ss, stdbuf, setsid and friends, so the
  # search path is spelled out instead of hoping for a profile.
  path = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.iproute2
    pkgs.nix
    pkgs.python3
    pkgs.util-linux
  ] + ":/run/current-system/sw/bin:/etc/profiles/per-user/${user}/bin";

  mkService =
    {
      description,
      execStart,
      stopSignal ? "SIGTERM",
      stopTimeout ? 30,
      restart ? "on-failure",
      extraServiceConfig ? { },
    }:
    {
      inherit description;
      wantedBy = [ "party.target" ];
      # PartOf makes `systemctl stop party` and `restart party` act on the unit;
      # wantedBy alone only pulls units up when the target starts.
      partOf = [ "party.target" ];
      after = [
        "network-online.target"
        "party-scoreboard.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = user;
        Group = "users";
        WorkingDirectory = repo;
        Environment = [
          "HOME=${home}"
          "PATH=${path}"
          "XDG_STATE_HOME=${home}/.local/state"
          "PYTHON=${pkgs.python3}/bin/python3"
        ];
        ExecStart = "${repo}/${execStart}";
        Restart = restart;
        RestartSec = 10;
        KillSignal = stopSignal;
        TimeoutStopSec = stopTimeout;
      } // extraServiceConfig;
    };
in
{
  systemd.targets.party = {
    description = "LAN party station (scoreboard and the four game servers)";
    wantedBy = [ "multi-user.target" ];
  };

  # The ingesters need it, and a rig that boots before the scoreboard should
  # still find boards up.
  systemd.services.party-scoreboard = mkService {
    description = "LAN party scoreboard (port 3000)";
    execStart = "scoreboard/run.sh";
    # The scoreboard server itself stops cleanly on SIGTERM and flushes SQLite.
    stopTimeout = 20;
  };

  systemd.services.party-ddnet = mkService {
    description = "LAN party DDNet server (8303/udp)";
    execStart = "scripts/ddnet-lan.sh";
  };

  systemd.services.party-stk = mkService {
    description = "LAN party SuperTuxKart server (2757 discovery, 2758 game)";
    execStart = "scripts/stk-lan.sh";
  };

  systemd.services.party-tmnf = mkService {
    description = "LAN party Trackmania station (five servers, 2350-2354)";
    execStart = "scripts/tmnf-lan.sh";
    # Ten processes: five servers plus five pollers.
    stopTimeout = 40;
  };

  # The UT99 launcher detaches the server and keeps a pid file, so the unit is
  # oneshot and stops through the same script rather than by signal.
  systemd.services.party-ut99 = {
    description = "LAN party UT99 server (7777/udp, 7778/udp query)";
    wantedBy = [ "party.target" ];
    partOf = [ "party.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        "HOME=${home}"
        "PATH=${path}"
        "XDG_STATE_HOME=${home}/.local/state"
      ];
      ExecStart = "${repo}/scripts/ut99-lan.sh dm";
      ExecStop = "${repo}/scripts/ut99-lan.sh kill";
      TimeoutStartSec = 120;
      TimeoutStopSec = 60;
    };
  };
}
