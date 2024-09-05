#!/bin/bash

if [ "$OMD_UPDATE" = "" ]; then
    echo "script requires OMD_UPDATE env variable"
    exit 1
fi

# try dry-run first (available since OMD 5.10)
DRYRUN=$(omd -V $OMD_UPDATE update -n 2>&1 | grep "conflicts during dry run" | awk '{ print $2 }')
if [ -n "$DRYRUN" -a "$DRYRUN" != "0" ]; then
    echo "no automatic update possible, $DRYRUN conflict(s) found."
    exit 1
fi

echo "[$(date)] updating site $(id -un) from $(omd version -b) to version $OMD_UPDATE..."

omd stop
# make sure it is stopped
omd status -b > /dev/null 2>&1
if [ $? -ne 1 ]; then
    omd stop
fi

CMD="omd -f -V $OMD_UPDATE update --conflict=ask"

# start update in tmux
if command -v tmux >/dev/null 2>&1; then
    session="omd_update"
    tmux new-session -d -s $session -x 120 -y 25
    window=0
    tmux rename-window -t $session:$window 'omd_update'
    tmux send-keys -t $session:$window "$CMD" C-m
    sleep 2

    # now wait till the omd update is finished and tail the output till then
    # end tmux on success
    bashpid=$(tmux list-panes -a -F "#{pane_pid} #{session_name}" | grep $session | awk '{ print $1 }')
    omdpid=$(ps -efl | grep $bashpid | grep omd | awk '{ print $4 }')
    X=0
    while [ $X -lt 10 ]; do
        omdpid=$(ps -efl | grep $bashpid | grep omd | awk '{ print $4 }')
        sleep 1
        X=$((X+1))
    done

    X=0
    while kill -0 $omdpid >/dev/null 2>&1; do
        sleep 1
        X=$((X+1))
        if [ $X -gt 120 ]; then
            echo "update failed, ssh into $HOSTNAME and run 'tmux attach -t $session:$window' to manually investigate"
            exit 1
        fi
    done
    tmux capture-pane -p -t $session:$window
else
    $CMD
fi

if [ "$(omd version -b)" = "$OMD_UPDATE" ]; then
    omd start
    echo "[$(date)] update finished: $(omd version -b)"

    # run post hook if available
    RC=0
    if [ -e "${OMD_ROOT}/var/tmp/omd_update_post.sh" ]; then
        echo "[$(date)] starting post update hook"
        bash -x ${OMD_ROOT}/var/tmp/omd_update_post.sh
        RC=$?
        rm -f ${OMD_ROOT}/var/tmp/omd_update_post.sh
        echo "[$(date)] post update hook exited: $RC"
    fi

    # exit tmux again
    if command -v tmux >/dev/null 2>&1; then
        tmux send-keys -t $session:$window "exit" C-m
    fi
    exit $RC
fi

echo "update failed, ssh into $HOSTNAME and run 'tmux attach -t $session:$window' to manually investigate"
exit 1