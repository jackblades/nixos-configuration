{ config, pkgs, ... }:

let pulse = pkgs.pulseaudioLight.override { jackaudioSupport = true; };
in {
  boot = {
    kernelModules = [ "snd-seq" "snd-rawmidi" ];
  };

  hardware.pulseaudio = {
    enable = true;
    package = pulse;
    support32Bit = true;
  };

  security.pam.loginLimits =
  [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
    { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
  ];

  environment.systemPackages = with pkgs; [ jack2Full ];

  systemd.user.services = {
     jackdbus = {
       description = "Runs jack, and points pulseaudio at it";
#       wantedBy = [ "default.target" ];
       requires = [ "pulseaudio.service" ];
       serviceConfig = {
         Type = "oneshot";
         ExecStart = pkgs.writeScript "start_jack" ''
           #! ${pkgs.bash}/bin/bash
           . ${config.system.build.setEnvironment}

           ${pkgs.jack2Full}/bin/jack_control start
           ${pulse.out}/bin/pacmd set-default-sink jack_out
           ${pulse.out}/bin/pacmd set-default-source jack_in

           SINK=$( ${pulse.out}/bin/pacmd list-sinks |
                   ${pkgs.gnugrep}/bin/grep -oE 'alsa_output.*analog-stereo')
           ${pulse.out}/bin/pactl suspend-sink $SINK 1
         '';
         ExecStop = pkgs.writeScript "stop_jack" ''
           #! ${pkgs.bash}/bin/bash
           . ${config.system.build.setEnvironment}

           SINK=$( ${pulse.out}/bin/pacmd list-sinks |
                   ${pkgs.coreutils}/bin/grep -oE 'alsa_output.*analog-stereo')
           ${pulse.out}/bin/pactl suspend-sink $SINK 0

           ${pkgs.jack2Full}/bin/jack_control stop
         '';
         RemainAfterExit = true;
       };
       environment = { DISPLAY = ":0"; };
     };
  };
}
