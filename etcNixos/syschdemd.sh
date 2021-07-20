#! @shell@

set -e

sw="/nix/var/nix/profiles/system/sw/bin"
systemPath=`${sw}/readlink -f /nix/var/nix/profiles/system`
SYSTEMD_PID="$($sw/ps -C systemd -o pid= | $sw/head -n1)"

# Needs root to work
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Requires root! :( Make sure the WSL default user is set to root"
    exit 1
fi

if [ ! -e "/run/current-system" ]; then
    LANG="C.UTF-8" /nix/var/nix/profiles/system/activate
fi

if [ -z "$SYSTEMD_PID" ]; then
    PATH=/run/current-system/systemd/lib/systemd:@fsPackagesPath@ \
        LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive \
        @daemonize@/bin/daemonize /run/current-system/sw/bin/unshare --fork --mount-proc --pid --propagation shared -- /bin/sh -c "
            $sw/mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
            exec systemd --unit=multi-user.target
            " &
    while [ -z "$SYSTEMD_PID" ]; do
            sw="/nix/var/nix/profiles/system/sw/bin"
            SYSTEMD_PID="$($sw/ps -C systemd -o pid= | $sw/head -n1)"
            $sw/sleep 2
    done

    while [ "$($sw/nsenter --mount --pid --target "$SYSTEMD_PID" -- $sw/systemctl is-system-running)" = "starting" ]; do
            $sw/sleep 2
    done

    echo "$SYSTEMD_PID" > /run/systemd.pid

    # Wait for systemd to start
    status=1
    while [[ $status -gt 0 ]]; do
        $sw/sleep 2
        status=0
        $sw/nsenter -t $SYSTEMD_PID -p -m -- \
                    $sw/systemctl is-system-running -q --wait 2>/dev/null \
            || status=$?
    done
fi

userShell=$($sw/getent passwd @defaultUser@ | $sw/cut -d: -f7)
if [[ $# -gt 0 ]]; then
    # wsl seems to prefix with -c
    shift
    cmd="$@"
else
    cmd="$userShell --login"
fi
exec $sw/nsenter -t "$SYSTEMD_PID" -p -m -- $sw/machinectl -q --uid=@defaultUser@ -E WSL_INTEROP=$WSL_INTEROP -E WSL_DISTRO_NAME=$WSL_DISTRO_NAME -E WSLENV=$WSLENV -E DISPLAY=$DISPLAY -E WAYLAND_DISPLAY=$WAYLAND_DISPLAY -E PULSE_SERVER=$PULSE_SERVER shell .host /bin/sh -c "exec $cmd"
