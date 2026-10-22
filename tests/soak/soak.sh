#!/usr/bin/env bash
# soak.sh  Runs virtualSessions in a MATLAB of its own until MATLAB crashes (WSL).
#
#   tests/soak/soak.sh [maxTrials]     sessions of maxTrials trials (default 800, about 2.5 hours)
#
# Each run gets D:\luminoseData\soak\<start time>\ with the driver's run_log.txt and this
# script's watchdog.txt. MATLAB ends cleanly when D:\luminoseData\soak\STOP exists
# (checked between sessions); any other end is a crash: the crash dumps, Windows' events
# and the session's log tail are copied into the run folder and the script stops.

maxTrials=${1:-800}
soak=/mnt/d/luminoseData/soak
run=$soak/$(date +%Y%m%d_%H%M%S)
matlab="/mnt/c/Program Files/MATLAB/R2025b/bin/matlab.exe"
here=$(wslpath -w "$(dirname "$(readlink -f "$0")")")
mkdir -p "$run"
rm -f "$soak/STOP"
note() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" | tee -a "$run/watchdog.txt"; }

touch "$run/.launch"
launched=$(date '+%Y-%m-%d %H:%M:%S')
note "MATLAB launched (maxTrials $maxTrials)"
"$matlab" -wait -sd "$here" -logfile "$(wslpath -w "$run")\\matlab_output.txt" -r "virtualSessions('$(wslpath -w "$run")', $maxTrials)"
code=$?
last=$(tail -n 1 "$run/run_log.txt" 2>/dev/null)
note "MATLAB exited with code $code; last log line: $last"

case "$last" in
    *"clean exit"*) note "stopped by STOP"; exit 0 ;;
    *"driver error"*) note "the driver failed (not a crash)"; exit 2 ;;
esac

note "CRASH: collecting"
mkdir -p "$run/crash"
for d in /mnt/c/Users/harrislab/AppData/Local/Temp /mnt/c/Users/harrislab/AppData/Local/CrashDumps /mnt/d/luminoseData/crashdumps; do
    find "$d" -maxdepth 1 -type f \( -name 'matlab_crash_dump.*' -o -iname 'MATLAB.exe*.dmp' \) \
        -newer "$run/.launch" -exec cp {} "$run/crash/" \; 2>/dev/null
done
powershell.exe -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime='$launched'; Id=1000,1001,1002} -ErrorAction SilentlyContinue | Where-Object { \$_.Message -match 'MATLAB' } | Format-List TimeCreated, Id, Message" \
    > "$run/crash/windows_events.txt" 2>&1
session=$(grep -oP 'started: \K.*' "$run/run_log.txt" | tail -n 1)
if [ -n "$session" ]; then
    log=$(wslpath -u "${session%.mat}_log.txt")
    tail -n 60 "$log" > "$run/crash/session_log_tail.txt" 2>/dev/null
fi
note "crash files: $(ls "$run/crash" | tr '\n' ' ')"
exit 1
