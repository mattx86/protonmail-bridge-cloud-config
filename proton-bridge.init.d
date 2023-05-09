#!/bin/bash

### BEGIN INIT INFO
# Provides:             proton-bridge
# Required-Start:       $network
# Required-Stop:        $network
# Default-Start:        2 3 4 5
# Default-Stop:         
# Short-Description:    Proton Mail Bridge
### END INIT INFO

SOCAT_IMAP_PIDFILE=/run/proton-bridge-socat-imap.pid
SOCAT_SMTP_PIDFILE=/run/proton-bridge-socat-smtp.pid
PROTON_BRIDGE_PIDFILE=/run/proton-bridge.pid

SOCAT_IMAP_PID=0
SOCAT_SMTP_PID=0
PROTON_BRIDGE_PID=0

PROTON_BRIDGE_EXEC=/usr/local/bin/proton-bridge
BRIDGE_EXEC=/usr/local/bin/bridge

start() {
  echo "Starting Proton Mail Bridge ..."

  status >/dev/null 2>&1

  if [ $SOCAT_IMAP_PID -gt 0 -o $SOCAT_SMTP_PID -gt 0 -o $PROTON_BRIDGE_PID -gt 0 ] ; then
    echo "Proton Mail Bridge is already running."
    status
    exit
  fi

  nohup socat TCP4-LISTEN:993,reuseaddr,fork,su=nobody TCP4:127.0.0.1:1993 >/dev/null 2>&1 &
  echo $! >$SOCAT_IMAP_PIDFILE

  nohup socat TCP4-LISTEN:587,reuseaddr,fork,su=nobody TCP4:127.0.0.1:1587 >/dev/null 2>&1 &
  echo $! >$SOCAT_SMTP_PIDFILE

  nohup su -P -s /bin/bash -c "$PROTON_BRIDGE_EXEC -n" - proton-bridge >/dev/null 2>&1 &
  echo $! >$PROTON_BRIDGE_PIDFILE
}

stop() {
  echo "Stopping Proton Mail Bridge ..."

  status >/dev/null 2>&1

  if [ $SOCAT_IMAP_PID -gt 0 ] ; then
    kill -9 $SOCAT_IMAP_PID
  fi

  if [ $SOCAT_SMTP_PID -gt 0 ] ; then
    kill -9 $SOCAT_SMTP_PID
  fi

  if [ $PROTON_BRIDGE_PID -gt 0 ] ; then
    kill -9 $PROTON_BRIDGE_PID
  fi

  /bin/rm -f $SOCAT_IMAP_PIDFILE $SOCAT_SMTP_PIDFILE $PROTON_BRIDGE_PIDFILE
}

restart() {
  stop
  sleep 1
  start
}

status() {
  SOCAT_IMAP_PID=$(pgrep -U 0 -f 'socat.*:1993' || echo 0)
  SOCAT_SMTP_PID=$(pgrep -U 0 -f 'socat.*:1587' || echo 0)
  PROTON_BRIDGE_PID=$(pgrep -f "^$BRIDGE_EXEC -n" || echo 0)
  
  if [ $SOCAT_IMAP_PID -eq 0 ] ; then
    echo "Socat IMAP: stopped"
  else
    echo "Socat IMAP: running [$SOCAT_IMAP_PID]"
  fi
  
  if [ $SOCAT_SMTP_PID -eq 0 ] ; then
    echo "Socat SMTP: stopped"
  else
    echo "Socat SMTP: running [$SOCAT_SMTP_PID]"
  fi
  
  if [ $PROTON_BRIDGE_PID -eq 0 ] ; then
    echo "Proton Mail Bridge: stopped"
  else
    echo "Proton Mail Bridge: running [$PROTON_BRIDGE_PID]"
  fi
}

[ "$1" == "status" ] && status && exit 0
[ "$1" == "start" ] && start && exit 0
[ "$1" == "stop" ] && stop && exit 0
[ "$1" == "restart" ] && restart && exit 0

echo "syntax: $0 <start|stop|restart|status>"
exit 0

