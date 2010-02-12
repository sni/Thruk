#!/bin/bash
#
# thruk_fastcgi_server.sh : thruk fastcgi daemon start/stop script
#
# version : 0.05
#
# chkconfig: 2345 84 16
# description: thruk fastcgi daemon start/stop script
# processname: fcgi
# pidfile: /private/tmp/thruk_fastcgi.pid
#
# 2010-02-12 by Sven Nierlein

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
prog="thruk"

EXECDIR=/Users/sven/projects/git/Thruk
PID=/private/tmp/thruk_fastcgi.pid
LOGFILE=/dev/null
PROCS=5
SOCKET=/private/tmp/thruk_fastcgi.socket


# your application environment variables

if [ -f "/etc/sysconfig/"$prog ]; then
  . "/etc/sysconfig/"$prog
fi

start() {
  if [ -f $PID ]; then
    echo "already running..."
      return 1
    fi
    # Start daemons.
    echo -n $"Starting Thruk: "
    touch ${LOGFILE}
    echo -n "["`date +"%Y-%m-%d %H:%M:%S"`"] " >> ${LOGFILE}
    if [ "$USER"x != "$EXECUSER"x ]; then
      cd ${EXECDIR};script/thruk_fastcgi.pl -n ${PROCS} -l ${SOCKET} -p ${PID} -d >> ${LOGFILE} 2>&1
    else
      cd ${EXECDIR}
      script/thruk_fastcgi.pl -n ${PROCS} -l ${SOCKET} -p ${PID} -d >> ${LOGFILE} 2>&1
    fi
    RETVAL=$?
    [ $RETVAL -eq 0 ] && success || failure $"$prog start"
    echo
    return $RETVAL
}

stop() {
  # Stop daemons.
  echo -n $"Shutting down Thruk: "
  echo -n "["`date +"%Y-%m-%d %H:%M:%S"`"] " >> ${LOGFILE}
  /bin/kill `cat $PID 2>/dev/null ` >/dev/null 2>&1 && (success; echo "Stoped" >> ${LOGFILE} ) || (failure $"$prog stop";echo "Stop failed" >> ${LOGFILE} )
  /bin/rm $PID >/dev/null 2>&1
  RETVAL=$?
  echo
  return $RETVAL
}

status() {
  # show status
  if [ -f $PID ]; then
    echo "${prog} (pid `/bin/cat $PID`) is running..."
  else
    echo "${prog} is stopped"
  fi
  return $?
}

restart() {
  stop
  start
}

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
    ;;
  *)
    echo $"Usage: $0 {start|stop|restart|status}"
    exit 1
esac
exit $?
