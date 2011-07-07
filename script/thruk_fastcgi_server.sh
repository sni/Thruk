#!/bin/bash
#
### BEGIN INIT INFO
# Provides:          thruk_fastcgi
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: startup script for thruk fastcgi server
# Description:       Thruk - Monitoring Webinterface. Gui for Nagios, Icinga and Shinken. 
### END INIT INFO
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
# execute script as $EXECUSER if the user is root
if [ "$USER" = "root" ];then
  SCRIPT=`readlink -f $0`
  su - $EXECUSER -c "$SCRIPT $*"
  exit $?
elif [ "$USER" != "$EXECUSER" ];then
    echo "wrong user, please use either user $EXECUSER or root"
    failure "$prog start"
    exit 1
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
    cd ${EXECDIR} && PM_MAX_REQUESTS=100 ./script/thruk_fastcgi.pl -n ${PROCS} -l ${SOCKET} -p ${PID} -M FCGI::ProcManager::MaxRequestsThruk -d >> ${LOGFILE} 2>&1 &
    for i in 1 2 3 4 5 6 7 8 9 0; do
      if [ -f $PID ]; then break; fi
      echo -n '.' && sleep 1;
    done
    echo -n " "
    status
    RETVAL=$?
    [ $RETVAL -eq 0 ] && success || failure "$prog start"
    return $?
}

################################
stop() {
  # Stop daemons.
  echo -n $"Shutting down Thruk: "
  echo -n "["`date +"%Y-%m-%d %H:%M:%S"`"] " >> ${LOGFILE}
  /bin/kill `cat $PID 2>/dev/null ` >/dev/null 2>&1 && (success; echo "Stoped" >> ${LOGFILE} ) || (failure "$prog stop";echo "Stop failed" >> ${LOGFILE} )
  /bin/rm $PID >/dev/null 2>&1
  RETVAL=$?
  return $RETVAL
}

################################
status() {
  # show status
  test -f $PID;
  rc=$?
  if [ $rc -eq 0 ]; then
    echo -n "${prog} (pid `/bin/cat $PID`) is running..."
  else
    echo -n "${prog} is stopped"
  fi
  return $rc
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
