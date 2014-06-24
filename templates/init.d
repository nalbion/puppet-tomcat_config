#!/bin/sh
#
# tomcat This shell script takes care of starting and stopping
# tomcat.
# description: tomcat is a servlet/JSP engine, which can be used
# standalone or in conjunction with Apache

### BEGIN INIT INFO
# Provides:             <%= @real_service_name %>
# Required-Start:       $local_fs $network $remote_fs apache2
# Required-Stop:        $local_fs $network $remote_fs apache2
# Default-Start:        3 5
# Default-Stop:         0 1 2 6
# Short-Description:    <%= @real_service_name %>
# Description:          <%= @real_service_name %>
### END INIT INFO

RETVAL=0
SHUTDOWN_WAIT=20

# http://tomcat.apache.org/tomcat-7.0-doc/RUNNING.txt
export CATALINA_HOME=<%= @catalina_home %>
export CATALINA_BASE=<%= @catalina_base %>

tomcat_pid() {
  echo `ps aux | grep 'tomcat-juli.jar.*-Dcatalina.base=<%= @catalina_base %>' | grep -v grep | awk '{ print $2 }'`
#  /var/lock/subsys/<%= @real_service_name %>
# "$CATALINA_BASE/tomcat.pid"
}

# https://gist.github.com/valotas/1000094
start() {
  pid=$(tomcat_pid)
  if [ -n "$pid" ] 
  then
    echo "Tomcat is already running (pid: $pid)"
  else
    # Start tomcat.
    echo -n "Starting <%= @real_service_name %>: "
#    cd ~<%= @owner %>
    su <%= @owner %> -c '<%= @catalina_home %>/bin/startup.sh'
    RETVAL=$?
      [ $RETVAL -eq 0 ] && touch /var/lock/subsys/<%= @real_service_name %>
    echo
  fi
}

stop() {
  pid=$(tomcat_pid)
  if [ -n "$pid" ]
  then
    # Stop tomcat.
    echo -n "Shutting down <%= @real_service_name %>: "
#    cd ~<%= @owner %>
#    # Andrew Alksnis added this hack because one of our apps does not shut down cleanly and needs to be killed 
#    # su - <%= @owner %> -c '<%= @catalina_home %>/bin/catalina.sh stop'
#    if [[ `id -un` == tomcat ]]; then
#      <%= @catalina_home %>/bin/catalina.sh stop
#      pkill -9 -f '<%= @real_service_name %>/endorsed'
#    else
#      su - <%= @owner %> -c '<%= @catalina_home %>/bin/catalina.sh stop'
#      su - <%= @owner %> -c 'pkill -9 -f <%= @real_service_name %>/endorsed'
#    fi

    su <%= @owner %> -c "<%= @catalina_home %>/bin/shutdown.sh"
        
    let kwait=$SHUTDOWN_WAIT
    count=0;
    until [ `ps -p $pid | grep -c $pid` = '0' ] || [ $count -gt $kwait ]
    do
      echo -n -e "\nwaiting for processes to exit";
      sleep 1
      let count=$count+1;
    done
 
    if [ $count -gt $kwait ]; then
      echo -n -e "\nkilling processes which didn't stop after $SHUTDOWN_WAIT seconds"
      kill -9 $pid
    fi
    
    RETVAL=$?
    [ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/<%= @real_service_name %>
    echo
  else
    echo "Tomcat is not running"
  fi
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
  pid=$(tomcat_pid)
  if [ -n "$pid" ]
  then
    echo "<%= @real_service_name %> is running with pid: $pid"
    RETVAL=0
  # program is dead and /var/run pid file exists -> RETVAL=1
  # program is dead and /var/lock lock file exists -> RETVAL=2
  else
    echo "<%= @real_service_name %> is not running"
    RETVAL=3
  fi
;; 
*)
echo "Usage: /etc/init.d/<%= @real_init_script %> {start|stop|restart|status}"
exit 1
esac

exit $RETVAL