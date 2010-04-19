#!/bin/bash
#
# thruk_fastcgi_server.sh : thruk fastcgi daemon start/stop script
#
# chkconfig: 2345 84 16
# description: thruk fastcgi daemon start/stop script
# processname: fcgi
# pidfile: /tmp/thruk_fastcgi.pid
#
# 2010-02-12 by Sven Nierlein

################################
# settings
prog="thruk"
EXECDIR=/home/thruk/Thruk
PID=/tmp/thruk_fastcgi.pid
LOGFILE=/dev/null
PROCS=5
SOCKET=/tmp/thruk_fastcgi.socket
EXECUSER=thruk
################################

# execute script as $EXECUSER if the user is root
if [ "$USER" = "root" ];then
  SCRIPT=`readlink -f $0`
  su - $EXECUSER -c "$SCRIPT $*"
  exit $?
elif [ "$USER" != "$EXECUSER" ];then
    echo "wrong user, please use either user $EXECUSER or root"
    failure $"$prog start"
    exit 1
fi

################################
# Load in the best success and failure functions we can find
if [ -f /etc/rc.d/init.d/functions ]; then
    . /etc/rc.d/init.d/functions
else
    # Else locally define the functions
    success() {
        echo -e "\n\t\t\t[ OK ]";
        return 0;
    }

    failure() {
        local error_code=$?
        echo -e "\n\t\t\t[ Failure ]";
        return $error_code
    }
fi

RETVAL=0
if [ -f "/etc/sysconfig/"$prog ]; then
  . "/etc/sysconfig/"$prog
fi

################################
# check pid file
if [ -f $PID ]; then
  ps -p `cat $PID` >/dev/null 2>&1;
  if [ $? != 0 ]; then
    echo "removed stale pid file";
    rm $PID;
  fi
fi

################################
start() {
  if [ -f $PID ]; then
    echo "already running..."
      return 1
    fi
    # Start daemons.
    echo -n $"Starting"
    touch ${LOGFILE}
    echo -n "["`date +"%Y-%m-%d %H:%M:%S"`"] " >> ${LOGFILE}
    cd ${EXECDIR} && PM_MAX_REQUESTS=100 ./script/thruk_fastcgi.pl -n ${PROCS} -l ${SOCKET} -p ${PID} -M FCGI::ProcManager::MaxRequests -d >> ${LOGFILE} 2>&1 &
    for i in 1 2 3 4 5 6 7 8 9 0; do
      if [ -f $PID ]; then break; fi
      echo -n '.' && sleep 1;
    done
    echo -n " "
    status
    RETVAL=$?
    [ $RETVAL -eq 0 ] && success || failure $"$prog start"
    return $?
}

################################
stop() {
  # Stop daemons.
  echo -n $"Shutting down Thruk: "
  echo -n "["`date +"%Y-%m-%d %H:%M:%S"`"] " >> ${LOGFILE}
  /bin/kill `cat $PID 2>/dev/null ` >/dev/null 2>&1 && (success; echo "Stoped" >> ${LOGFILE} ) || (failure $"$prog stop";echo "Stop failed" >> ${LOGFILE} )
  /bin/rm $PID >/dev/null 2>&1
  RETVAL=$?
  return $RETVAL
}

################################
status() {
  # show status
  if [ -f $PID ]; then
    echo -n "${prog} (pid `/bin/cat $PID`) is running..."
  else
    echo -n "${prog} is stopped"
  fi
  return $?
}

################################
restart() {
  stop
  start
}

################################
# See how we were called.
case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  status)
    status
    echo " "
    ;;
  *)
    echo $"Usage: $0 {start|stop|restart|status}"
    exit 1
esac
exit $?
