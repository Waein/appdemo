#!/bin/bash

# ----------------------- header begin --------------------------
# The default variable
CHECK_PORT=1
USER_HOME=/home/admin
OUTPUT_HOME=${USER_HOME}/output
APP_HOME=${USER_HOME}/${APPNAME}
if [ "${APP_RUN_MODE}" != "fg" ] && [ "${MULTIPLE_TRUNK_DEPLOY}" = "true" ] && [ "${CHECKOUT_FROM}" != "master" ]
then
    APP_HOME=/home/admin/${APPNAME}-${CHECKOUT_FROM}
fi
APP_OUTPUT=${OUTPUT_HOME}/${APPNAME}
HOSTNAME=$(hostname)
LOCALIP=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"|head -1`
# shellcheck disable=SC2034
CPU=4
# shellcheck disable=SC2034
MEM=8
# shellcheck disable=SC2034
SFX="2>&1 &"

TEXT_CICD_TEAM="请联系容器云团队"
# shellcheck disable=SC2034
TEXT_FILE_NOT_EXIST="文件不存在，${TEXT_CICD_TEAM}"
# shellcheck disable=SC2034
TEXT_FAILED=" failed..."
TEXT_RELEASE_APP_PORT="sudo netstat -nlpt|grep ${APP_PORT:-8088}|awk -F \"[ /]+\" '{print $7}'|xargs kill -9"

die() {
    if [ $# != 2 ] ; then
        echo " The first is return code,the second error message!"
        echo " e.g.: die 1 'error message'"
        exit 1;
    fi
    code=$1
    msg=$2
    result="error"
    if [ "$code" = "0" ];then
        result="success"
    fi
    echo "[DragonSystem] [start.sh] [$result] [${msg}]" && exit "${code}"
}

get_app_name() {
    if [ "$APP_RUN_MODE" != "fg" ] && [ -z "$APPNAME" ]; then
        echo "[DragonSystem] [start.sh] [begin] [检测到当前为虚拟机中应用启动]"
        APP_NAME_VM=$(ls /home/admin/ | grep -v arthas | grep -v output | grep -v rasp | grep -v open-falcon | grep -v .log | grep -v .bak | grep -v .nimitz | grep -v .cicd | grep -v app_conf | head -1)
        if [ APP_NAME_VM = "" ]; then
            die 2 "[DragonSystem] [start.sh] [failed] 尝试自动获取应用名失败，请手动执行source env.sh，注入预置的环境变量"
        fi
        if [ -f "${USER_HOME}/${APP_NAME_VM}/start.sh" ]; then
            echo "[DragonSystem] [start.sh] [begin] [获取到应用名为${APP_NAME_VM}]"
            export APPNAME=${APP_NAME_VM}
            APP_HOME=${USER_HOME}/${APPNAME}
            APP_OUTPUT=${OUTPUT_HOME}/${APPNAME}
        else
            echo "[DragonSystem] [start.sh] [begin] [获取到应用名为${APP_NAME_VM}，但找不到启动脚本，若获取不正确，请先到应用目录下手动source env.sh]"
        fi
    fi
}

source_env() {
    echo "[DragonSystem] [start.sh] [begin] [应用启动前检查开始]"
    if [ "$APP_RUN_MODE" != "fg" ]; then
        if [ -f "${APP_HOME}/env.sh" ]; then
            # shellcheck source=/home/admin/$APPNAME/env.sh
            # shellcheck disable=SC1091
            . "${APP_HOME}/env.sh" || die 501 "source env.sh params error!"
            # 若虚拟机中非8088，则进行替换，替换成真正的端口号
            if [ "$APP_PORT" != "8088" ];then
                TEXT_RELEASE_APP_PORT="${TEXT_RELEASE_APP_PORT/8088/$APP_PORT}"
            fi
            # 若为spark发布,则不用做端口检查
            if [ "$DEPLOY_SPARK_ENV" ];then
                CHECK_PORT=2
            fi
        else
            die 2 "CICD容器平台未在${APP_HOME}目录下生成env.sh(环境变量配置文件)，${TEXT_CICD_TEAM}"
        fi
    fi
}

source_preboot() {
    if [ -f "${APP_HOME}/preboot" ]; then
        # shellcheck source=/home/admin/$APPNAME/preboot
        # shellcheck disable=SC1091
        . "${APP_HOME}/preboot" || die 501 "source preboot params error!"
        echo "[DragonSystem] [start.sh] [running] [应用启动前激活preboot中定义的环境变量或执行逻辑完成]"
    fi
}

# For the log
generate_log_dir() {
    if [ "$APP_RUN_MODE" = "fg" ]; then
        CONTAINERS_DIR=/.containers
        mkdir -p "${CONTAINERS_DIR}/$HOSTNAME" || die 505 "容器中运行当前命令角色不对，必须使用root执行，当前为$(whoami), ${TEXT_CICD_TEAM}"
        # mounted log directory and export env to info
        if [ ! -L ${OUTPUT_HOME} ]; then
            ln -s ${CONTAINERS_DIR}/$HOSTNAME ${OUTPUT_HOME}
            # export |awk '{print $3}' > ${OUTPUT_HOME}/info
            env > ${OUTPUT_HOME}/info
        fi
       echo "[DragonSystem] [start.sh] [running] [应用启动前生成应用输出目录${OUTPUT_HOME}完成]"
    fi
}

# for traffic switch
generate_traffic_switch() {
    if [ "$APP_RUN_MODE" = "fg" ] && [ ! -f "${USER_HOME}/.traffic_switch" ]; then
        touch "${USER_HOME}/.traffic_switch"
        echo "[DragonSystem] [start.sh] [running] [应用启动前生成应用流量控制标识完成]"
    fi
}

# make sure env $APPNAME, $DC, $CLUSTER, $ENV, $GRAYLOG_HOST, $GRAYLOG_PORT, $SHUTTER, LIMIT_CPU, LIMIT_MEM are all set
check_env() {
    # 进行错误提示，若用户环境中的shell默认是sh，非bash，则肯定会报错，
    # echo "[DragonSystem] [start.sh] [running] [若遇到如下错误'/home/admin/$APPNAME/start.sh: $((LINENO+1)): /home/admin/$APPNAME/start.sh: Syntax error: \"(\" unexpected (expecting \"}\")',请修改Dockerfile中的CMD [\"/bin/bash\", \"-c\" ,\"sh /home/admin/$APPNAME/start.sh\" ]->CMD [\"/bin/bash\", \"-c\" ,\"bash /home/admin/$APPNAME/start.sh\" ]]"
    # 使用Bourne shell中格式，避免不兼容问题
    set 'APPNAME' 'DC' 'ENV' 'CLUSTER' 'APP_PORT'
    for check_env in "$@";
    do
        # 添加默认值
        check_val=""
        eval check_val=\$$check_env
        # 两层取值${!check_env}=>$check_env=APPNAME&&$APPNAME（在bash中有用，在Bourne shell中无效
        if [ -z "$check_val" ]; then
            die 256 "CICD平台未注入环境变量${check_env}, ${TEXT_CICD_TEAM}"
        fi
    done

    if [ "${APP_RUN_MODE}" = "fg" ] && [ -z "$LIMIT_CPU" ]; then
        die 256 "容器中，CICD平台未注入环境变量LIMIT_CPU，${TEXT_CICD_TEAM}"
    fi
    if [ "${APP_RUN_MODE}" = "fg" ] && [ -z "$LIMIT_MEM" ]; then
        die 256 "容器中，CICD平台未注入环境变量LIMIT_MEM，${TEXT_CICD_TEAM}"
    fi

    if [ "$CHECK_PORT" = "1" ] && [ "$APP_RUN_MODE" != "fg"  ]; then
        STR=$(netstat -an|grep -v grep |grep -v LISTENING|grep LISTEN|grep -v "^tcp6"|awk -F "[ :]+" '{print $5}'|awk '$1 == APP_PORT' APP_PORT="${APP_PORT}")
        if [ ! -z "$STR" ]; then

            die 502 "虚拟机中，端口${APP_PORT}已被占用，请释放端口再试。请上ops上选中机器，使用ops平台(ops.tongdun.cn)脚本执行命令(请使tdops账户,若无，申请zeus堡垒机工单)或上机器使用tdops账号执行, ${TEXT_RELEASE_APP_PORT}"
        fi
    fi

    if [ ! -d "$APP_OUTPUT/logs" ]; then
        mkdir -p "${APP_OUTPUT}/logs"
    fi

    echo "[DragonSystem] [start.sh] [running] [开始输出当前执行环境环境变量]"
    echo "####################################################################"
    env|grep -v "LS_COLORS\\|PROMPT_COMMAND"
    echo ""
    echo ""
    echo "####################################################################"
}

# ----------------------- header end --------------------------
# append user start.sh content
start() {
    # 切换到应用目录
    cd "${APP_HOME}" || die 2 "应用目录不存在，请点击重试发布"

    # shellcheck disable=SC2154

# logs
mkdir -p logs

# preboot
if [ -f ./preboot ]; then
    . ./preboot || exit 1
fi

JVM_EXT_PARAM_CONTENT="${JVM_EXT_PARAM// /}"

# envs
envs=(APPNAME APP_PORT LIMIT_CPU LIMIT_MEM ENV)
for e in "${envs[@]}";
do
    val=""
    eval val=\$$e
    if [ -z "$val" ]; then
        echo "没有设置环境变量${e}" && exit 1
    fi
done

if [ "${LIMIT_CPU:-1}" = "m" ]; then
    CPU=1
else
    CPU=${LIMIT_CPU}
fi

mem_last2char=${LIMIT_MEM:0-2}
mem_last2char=$(echo "${mem_last2char}"|tr "[:upper:]" "[:lower:]")

if [ "${mem_last2char}" = "gi" ]; then
    MEM=$(echo "${LIMIT_MEM:0:-2}"|awk '{printf "%d", $1 }')
elif [ "${mem_last2char}" = "mi" ]; then
    MEM=$(echo "${LIMIT_MEM:0:-2}"|awk '{printf "%d", $1/1024 }')
elif [ "${mem_last2char}" = "ki" ]; then
    MEM=$(echo "${LIMIT_MEM:0:-2}"|awk '{printf "%d", $1/1024/1024 }')
else
    # LIMIT_MEM为数值，例如LIMIT_MEM=8
    MEM=$(echo "${LIMIT_MEM}"|awk '{printf "%d", $1 }')
fi

if [ -z "${JVM_EXT_PARAM}" ] || [ "${#JVM_EXT_PARAM_CONTENT}" = "0" ]; then
    JVM_EXT_PARAM="-server -XX:MaxMetaspaceSize=256m -Xss256k -XX:+UseG1GC -XX:MaxGCPauseMillis=100 $JVM_EXT_PARAM"
    JVM_EXT_PARAM="-XX:G1ReservePercent=10 -XX:InitiatingHeapOccupancyPercent=30 $JVM_EXT_PARAM"
    JVM_EXT_PARAM="-XX:ConcGCThreads=$CPU -XX:ParallelGCThreads=$CPU $JVM_EXT_PARAM"
    if [ "${MEM}" = "8" ]; then
        JVM_EXT_PARAM="-Xmx6g -Xms6g $JVM_EXT_PARAM"
    elif [ "${MEM}" = "4" ]; then
        JVM_EXT_PARAM="-Xmx3g -Xms3g $JVM_EXT_PARAM"
    else
        # 其它情况，使用75%的内存设置Xmx和Xms
        EIGHTY_PERCENT_MEM=$(echo "${MEM}"|awk '{printf "%d", $1*1024*0.75 }')
        JVM_EXT_PARAM="-Xmx${EIGHTY_PERCENT_MEM}m -Xms${EIGHTY_PERCENT_MEM}m $JVM_EXT_PARAM"
    fi
fi

# 测试环境下载agent及添加启动专用jvm启动参数
test_env_arr=(test dev smoke test-common)
for e in "${test_env_arr[@]}"
do
   if [ "${e}" = "${ENV}" ]; then
        if [ "${APP_TEST_AGENT}" = 1 ]; then
            wget -c --tries=3  http://ci-agent-jar.ci.svc.cluster.local/router-agent.jar
            if [ -f "router-agent.jar" ]; then
                local_path=$(pwd)
                if [  ! -z "${APP_TEST_TAG}" ]; then
                    JVM_EXT_PARAM="-javaagent:${local_path}/router-agent.jar -DtestTag=${APP_TEST_TAG} ${JVM_EXT_PARAM}"
                else
                    JVM_EXT_PARAM="-javaagent:${local_path}/router-agent.jar ${JVM_EXT_PARAM}"
                fi
            fi
        fi
        break
   fi
done

#add default jvm parameters
JVM_EXT_PARAM="-XX:+PrintJNIGCStalls $JVM_EXT_PARAM"
JVM_EXT_PARAM="-XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=10M -Xloggc:./logs/gc.log -XX:+PrintGCApplicationStoppedTime $JVM_EXT_PARAM"
JVM_EXT_PARAM="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=./ $JVM_EXT_PARAM"
# JVM_EXT_PARAM="-XX:NativeMemoryTracking=detail $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Djava.awt.headless=true -Djava.net.preferIPv4Stack=true -Dfile.encoding=UTF-8 $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Djava.net.preferIPv4Addresses -DdisableIntlRMIStatTask=true $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Dcom.sun.management.jmxremote -XX:+PrintGCDateStamps -XX:+PrintGCDetails $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Dcom.sun.management.jmxremote.authenticate=false $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Dcom.sun.management.jmxremote.local.only=false $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=10055 $JVM_EXT_PARAM"
JVM_EXT_PARAM="-Djava.rmi.server.hostname=$LOCALIP $JVM_EXT_PARAM"

exec_str="java ${JVM_EXT_PARAM} -jar ${APPNAME}.jar \
               --app.name=${APPNAME}\
               --server.port=${APP_PORT}\
               --spring.profiles.active=${ENV}\
               ${APP_EXT_PARAM}"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -d)
            DAEMON=YES
            shift # past argument
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ "${DAEMON}" = "YES" ];
then
    exec_str="nohup ${exec_str} < /dev/null > /dev/null 2>&1 &"
fi

eval "${exec_str}"

test_env_arr=(test dev smoke test-common)
for e in "${test_env_arr[@]}"
do
if [ "${e}" = "${ENV}" ]; then
if [ "${JACOCO_AGENT}" = "true" ] && [ -n "${JACOCO_PORT}" ] ; then
wget -c --tries=3 http://ci-agent-jar.ci.svc.cluster.local/jacocoagent.jar
if [ -f "jacocoagent.jar" ]; then
local_path=$(pwd)
JVM_EXT_PARAM="-javaagent:${local_path}/jacocoagent.jar=includes=*,output=tcpserver,port=${JACOCO_PORT},address=*"
fi

fi
break
fi
done
    # It is forbidden to remove newline

    # 生成pid信息
    pid=$!
    mkdir -p "/var/tmp/" || die 2 "创建pid目录/var/tmp失败，请检查是否有权限创建，之后再重试"
    echo "$pid" > "/var/tmp/$APPNAME.pid"
}

# ----------------------- footer begin --------------------------
waitfor() {
    STARTTIME=$(date +"%s")
    COUNT=1
    sleep 5
    # TODO 虚拟机没有健康检查配置，使用ok端口检查或脚本检查
    if [ "$APP_RUN_MODE" != "fg" ]; then
        while true
        do
            ENDTIME=$(date +"%s")
            COSTTIME=$((ENDTIME - STARTTIME))

            if [ "${COUNT}" -ge 175 ]; then
                echo ""
                rm -f "/var/tmp/$APPNAME.pid" || die 2 "删除pid失败，请上机器手动删除"
                die 503 "Waited for 3 minutes and aborted"
            fi

            if [ -f "${APP_HOME}/validate.sh" ]; then
                sh "${APP_HOME}/validate.sh"
                if [ "$?" = "0" ]; then
                    pid=$(netstat -nlpt|grep "${APP_PORT:-8088}"|grep -v "^tcp6"|awk -F "[ /]+" '{print $7}')
                    echo ""
                    die 0 "APP started with pid $pid in $COSTTIME seconds."
                else
                    sleep 1
                    COUNT=$((COUNT + 1))
                    echo -n -e "\\rWait for booting: $COSTTIME seconds"
                    continue
                fi
            else
                http_code=$(curl --connect-timeout 1 -I -m 1 -o /dev/null -s -w "%{http_code}" http://127.0.0.1:${APP_PORT}/ok.htm)


                if [ "$http_code" = "000" ]; then
                    sleep 1
                    COUNT=$((COUNT + 1))
                    echo -n -e "\\rWait for booting: $COSTTIME seconds"
                    continue
                fi

                if [ "$http_code" = "200" ]; then
                    pid=$(netstat -nlpt|grep "${APP_PORT:-8088}"|grep -v "^tcp6"|awk -F "[ /]+" '{print $7}')
                    echo ""
                    die 0 "APP started with pid $pid in $COSTTIME seconds."
                else
                    echo ""
                    rm -f "/var/tmp/$APPNAME.pid" || die 2 "删除pid失败，请上机器手动删除"
                    die 500 "ERROR: APP failed to start!!!"
                fi
            fi
        done
    fi
}

main() {
    get_app_name
    source_env
    source_preboot
    generate_log_dir
    generate_traffic_switch
    check_env
    start
    waitfor
}
main
# ----------------------- footer end --------------------------