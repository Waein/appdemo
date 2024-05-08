#!/bin/bash

DATE=$(date +%Y%m%d%H%M%S)
FILE_PATH=$(realpath "$0")
APP_HOME=$(dirname "$FILE_PATH")

################################################################################################################

#G1 opitons
#JAVA_MEM_OPTS="-server -Xms6g -Xmx6g  -XX:MaxMetaspaceSize=512m -Xss256k -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1ReservePercent=30 -XX:InitiatingHeapOccupancyPercent=30 -XX:ConcGCThreads=4"
#ParallelGC options
JAVA_MEM_OPTS="-server -Xms2g -Xmx2g -XX:MetaspaceSize=512m -XX:MaxMetaspaceSize=512m -XX:NewRatio=1 -XX:SurvivorRatio=8 -XX:+UseParallelGC -XX:+UseParallelOldGC"
SPRING_LOADER_PATH=$APP_HOME/libs

#JMX="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=1091 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"

################################################################################################################
echo
echo
echo "APP_HOME: $APP_HOME"
cd "$APP_HOME" || exit

APP_JAR_NAME=$2
if [ -z "$APP_JAR_NAME" ]; then
  APP_JAR_NAME=$(ls -t -1 | grep .jar$ | head -n1)
fi
JAR_FILE=$APP_HOME/$APP_JAR_NAME

if [ ! -f "$JAR_FILE" ]; then
  echo "jar file path: $JAR_FILE, jar包不存在"
  exit 1
fi
echo "jar file: $JAR_FILE"

CONFIG_PATH=$3
if [ -z "$CONFIG_PATH" ]; then
  CONFIG_PATH=$(ls -t -1 | grep .properties$ | head -n1)
fi
if [ -z "$CONFIG_PATH" ]; then
  CONFIG_PATH=$(ls -t -1 | grep .yml$ | head -n1)
fi

CONFIG_PATH=$APP_HOME/$CONFIG_PATH
if [ ! -f "$CONFIG_PATH" ]; then
  echo "config file path: $CONFIG_PATH, 配置文件不存在"
  exit 1
fi

echo "CONFIG_PATH: $CONFIG_PATH"

SERVER_NAME=$(basename "$APP_JAR_NAME" .jar)
LOG_PATH=$APP_HOME/logs/$SERVER_NAME.outs
GC_LOG_PATH=$APP_HOME/logs/gc-$SERVER_NAME-$DATE.log

mkdir -p "$APP_HOME"/logs

SPRING_BOOT_OPTS="-Dname=$SERVER_NAME -Dspring.config.location=$CONFIG_PATH"
if [ -n "$SPRING_LOADER_PATH" ]; then
  SPRING_BOOT_OPTS="$SPRING_BOOT_OPTS -Dloader.path=$SPRING_LOADER_PATH"
fi
JVM_OPTS="-Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Duser.timezone=Asia/Shanghai -XX:+HeapDumpOnOutOfMemoryError -XX:+PrintGCDateStamps -Xloggc:$GC_LOG_PATH -XX:+PrintGCDetails"
JVM_OPTS="$JAVA_MEM_OPTS $JVM_OPTS $SPRING_BOOT_OPTS $JMX"

echo "SERVER_NAME: $SERVER_NAME"
echo "LOG_PATH: $LOG_PATH"
echo "GC_LOG_PATH: $GC_LOG_PATH"
echo "APP_JAR_NAME: $APP_JAR_NAME"
echo "JVM_OPTS: $JVM_OPTS"
echo
echo

function read_property() {
  local file_name=$1
  local property_name=$(echo $2 | sed 's/\./\\\./g')
  cat ${file_name} | sed -n -e "s/^[ ]*//g;/^#/d;s/^$property_name=//p" | tail -1
}

function checkpid() {
  pid=$(ps -ef | grep "$JAR_FILE" | grep -v "grep" | awk '{print $2}')
}

function read_app_port(){
    TIMEOUT=180
    STARTTIME=$(date +"%s")
    while [ $TIMEOUT -gt 0 ]; do
        ENDTIME=$(date +"%s")
        COSTTIME=$(($ENDTIME - $STARTTIME))
        if [ $COSTTIME -ge $TIMEOUT ]; then
            break
        fi
        if [ -e "application.port" ]; then
            APP_PORT=`cat application.port | head -n1 `
            break
        else
            sleep 1
            echo -n -e "\rWait app to start: $COSTTIME seconds"
            continue
        fi
    done
    if [ $COSTTIME -ge $TIMEOUT ]; then
        echo
        echo "App start timeout in $TIMEOUT seconds,App start failed."
        echo -1
    fi
}

function start() {
  checkpid
  if [ -z "$pid" ]; then

    if [ -e "application.port" ]; then
      rm application.port
    fi

    STARTTIME=$(date +"%s")
    exec nohup java -jar $JVM_OPTS $JAR_FILE >"$LOG_PATH" 2>&1 &

    read_app_port

    echo "---------------------------------"
    echo "应用 $SERVER_NAME (端口: $APP_PORT) 启动中>>>>>"
    echo "---------------------------------"
    sleep 2s

    TIMEOUT=180
    CHECK_STARTUP_URL="http://localhost:$APP_PORT/ok.htm"
    while [ $TIMEOUT -gt 0 ]; do
      RESULT=$(curl --connect-timeout 1 -s $CHECK_STARTUP_URL)
      ENDTIME=$(date +"%s")
      COSTTIME=$(($ENDTIME - $STARTTIME))

      if [ $COSTTIME -ge $TIMEOUT ]; then
        break
      fi

      if [ -z "$RESULT" ]; then
        sleep 1
        echo -n -e "\rWait app $SERVER_NAME to start: $COSTTIME seconds"
        continue
      fi

      COUNT=$(echo "$RESULT" | grep -c -i OK)
      if [ "$COUNT" -ge 1 ]; then
        checkpid
        echo
        echo "App $SERVER_NAME(pid:$pid) started in $COSTTIME seconds."
        rm $LOG_PATH
        echo 0
        return
      else
        echo "ERROR: Start APP $SERVER_NAME Failed!!!"
        echo -1
        exit
      fi
    done

    if [ $COSTTIME -ge $TIMEOUT ]; then
      echo
      echo "App $SERVER_NAME start timeout in $TIMEOUT seconds, $SERVER_NAME start failed."
      echo "check log files in $LOG_PATH."
      echo -1
    fi
  else
    echo "App $SERVER_NAME(pid:$pid) is running."
    echo 0
  fi
}

function stop() {
  checkpid
  if [ -z "$pid" ]; then
    echo "App $SERVER_NAME is not running."
    return
  fi

  echo "---------------------------------"
  echo "应用 $SERVER_NAME(pid:$pid) 关闭中>>>>>"
  echo "---------------------------------"

  kill $pid
  RETVAL=$?
  checkpid
  TIMEOUT=30
  COSTTIME=1
  while [ $RETVAL = 0 ] && [ $COSTTIME -le $TIMEOUT ] && [ -n "$pid" ]; do
    sleep 1
    echo -n -e "\rWait app $SERVER_NAME(pid:$pid) to stop: $COSTTIME seconds."
    ((COSTTIME++))
    checkpid
  done

  echo
  if [ $COSTTIME -ge $TIMEOUT ]; then
    echo "App $SERVER_NAME stop timeout in $TIMEOUT seconds, force killed."
    kill -9 "$pid" >/dev/null 2>&1
  fi

  echo "App $SERVER_NAME stopped."
}

restart() {
  stop
  sleep 3s
  start
}

status() {
  checkpid
  if [ -n "$pid" ]; then
    echo "App $SERVER_NAME(pid $pid) is running..."
    return 0
  fi
  echo "App $SERVER_NAME is stopped."
}

dump() {
  LOGS_DIR=$APP_HOME/logs/
  DUMP_DIR=$LOGS_DIR/dump
  if [ ! -d "$DUMP_DIR" ]; then
    mkdir "$DUMP_DIR"
  fi
  DUMP_DATE=$(date +%Y%m%d%H%M%S)
  DATE_DIR=$DUMP_DIR/$DUMP_DATE
  if [ ! -d "$DATE_DIR" ]; then
    mkdir "$DATE_DIR"
  fi

  echo -e "Dumping the $SERVER_NAME ...\c"

  PIDS=$(ps -ef | grep java | grep "$JAR_FILE" | awk '{print $2}')
  for PID in $PIDS; do
    jstack $PID >$DATE_DIR/jstack-$PID.dump 2>&1
    echo -e "PID=$PID .\c"
    jinfo $PID >$DATE_DIR/jinfo-$PID.dump 2>&1
    echo -e ".\c"
    jstat -gcutil $PID >$DATE_DIR/jstat-gcutil-$PID.dump 2>&1
    echo -e ".\c"
    jstat -gccapacity $PID >$DATE_DIR/jstat-gccapacity-$PID.dump 2>&1
    echo -e ".\c"
    jmap $PID >$DATE_DIR/jmap-$PID.dump 2>&1
    echo -e ".\c"
    jmap -heap $PID >$DATE_DIR/jmap-heap-$PID.dump 2>&1
    echo -e ".\c"
    jmap -histo $PID >$DATE_DIR/jmap-histo-$PID.dump 2>&1
    echo -e ".\c"
    if [ -r /usr/sbin/lsof ]; then
      /usr/sbin/lsof -p $PID >$DATE_DIR/lsof-$PID.dump
      echo -e ".\c"
    fi
  done

  if [ -r /bin/netstat ]; then
    /bin/netstat -an >$DATE_DIR/netstat.dump 2>&1
    echo -e "netstat.dump ..."
  fi
  if [ -r /usr/bin/iostat ]; then
    /usr/bin/iostat >$DATE_DIR/iostat.dump 2>&1
    echo -e "iostat.dump ..."
  fi
  if [ -r /usr/bin/mpstat ]; then
    /usr/bin/mpstat >$DATE_DIR/mpstat.dump 2>&1
    echo -e "mpstat.dump ..."
  fi
  if [ -r /usr/bin/vmstat ]; then
    /usr/bin/vmstat >$DATE_DIR/vmstat.dump 2>&1
    echo -e "vmstat.dump ..."
  fi
  if [ -r /usr/bin/free ]; then
    /usr/bin/free -t >$DATE_DIR/free.dump 2>&1
    echo -e "free.dump ..."
  fi
  if [ -r /usr/bin/sar ]; then
    /usr/bin/sar >$DATE_DIR/sar.dump 2>&1
    echo -e ".\c"
  fi
  if [ -r /usr/bin/uptime ]; then
    /usr/bin/uptime >$DATE_DIR/uptime.dump 2>&1
    echo -e ".\c"
  fi

  echo "OK!"
  echo "DUMP: $DATE_DIR"
  echo 0
}

case $1 in
start)
  start
  ;;
stop)
  stop
  ;;
restart)
  restart
  ;;
status)
  status
  ;;
dump)
  dump
  ;;
*) echo "require start|stop|restart|status|dump" ;;
esac