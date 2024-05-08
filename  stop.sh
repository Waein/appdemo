#!/bin/bash

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
    echo "[DragonSystem] [stop.sh] [$result] [${msg}]" && exit "${code}"
}

USER_HOME=/home/admin
APP_HOME="${USER_HOME}/${APPNAME}"
if [ "${APP_RUN_MODE}" != "fg" ] && [ "${MULTIPLE_TRUNK_DEPLOY}" = "true" ] && [ "${CHECKOUT_FROM}" != "master" ]
then
    APP_HOME=/home/admin/${APPNAME}-${CHECKOUT_FROM}
fi
TEXT_CICD_TEAM="请联系容器云团队"
# shellcheck disable=SC2034
TEXT_FILE_NOT_EXIST="文件不存在，${TEXT_CICD_TEAM}"
# shellcheck disable=SC2034
TEXT_FAILED=" failed..."
# shellcheck disable=SC2034
TEXT_RELEASE_APP_PORT="sudo netstat -nlpt|grep ${APP_PORT:-8088}|awk -F \"[ /]+\" '{print $7}'|xargs kill -9"

get_app_name() {
    if [ "$APP_RUN_MODE" != "fg" ]; then
        echo "[DragonSystem] [stop.sh] [begin] [检测到当前为虚拟机中应用关闭]"
        APP_NAME_VM=$(ls /home/admin/ | grep -v arthas | grep -v output | grep -v rasp | grep -v open-falcon | grep -v .log | grep -v .bak | grep -v .nimitz | grep -v .cicd | grep -v app_conf | head -1)
        if [ APP_NAME_VM = "" ]; then
            die 2 "[DragonSystem] [stop.sh] [failed] 尝试自动获取应用名失败，请到应用目录下手动执行source env.sh，注入预置的环境变量"
        fi
        if [ -f "${USER_HOME}/${APP_NAME_VM}/start.sh" ]; then
            echo "[DragonSystem] [stop.sh] [begin] [获取到应用名为${APP_NAME_VM}]"
            export APPNAME=${APP_NAME_VM}
            APP_HOME=${USER_HOME}/${APPNAME}
        else
            echo "[DragonSystem] [stop.sh] [begin] [获取到应用名为${APP_NAME_VM}，但找不到启动脚本，若获取不正确，请先到应用目录下手动执行source env.sh]"
        fi
    fi
}

source_env() {
    echo "[DragonSystem] [stop.sh] [begin] [应用停止前检查开始]"
    if [ -f "${APP_HOME}/env.sh" ]; then
        # shellcheck source=/home/admin/$APPNAME/env.sh
        # shellcheck disable=SC1091
        . "${APP_HOME}/env.sh" || die 501 "source env.sh params error!"
    fi
}

# 校验环境变量，若环境变量不存在，则报类似的错误
check_env() {
    if [ -z "$APPNAME" ]; then
        die 256 "env APPNAME is not set!"
    fi

    if [ -z "$APP_PORT" ]; then
        APP_PORT=8088
    fi
    echo "[DragonSystem] [stop.sh] [running] [开始输出应用关闭时使用环境变量]"
    echo "####################################################################"
    env|grep -v "LS_COLORS\\|PROMPT_COMMAND"
    echo ""
    echo ""
    echo "####################################################################"
}

stop() {
    # 针对8088端口未监听进程存在情况
    o_pid=""
    pid=$(netstat -nlpt|grep "${APP_PORT:-8088}"|grep -v "^tcp6"|awk -F "[ /]+" '{print $7}')
    if [ -f "/var/tmp/$APPNAME.pid" ] && [ -z "$pid" ];then
        o_pid=$(cat "/var/tmp/$APPNAME.pid")
        if [ ! -z "$o_pid" ]; then
            kill -9 "${o_pid}" || die 701 "端口查询进程失败，强杀进程PID=$o_pid失败，请上服务器使用tdops用户执行${TEXT_RELEASE_APP_PORT}，手动强杀进程；后续请改造应用，避免出现这种问题"
        fi
        rm -fr "/var/tmp/$APPNAME.pid" || die 2 "删除/var/tmp/$APPNAME.pid进程文件失败,请上服务器使用tdops用户删除此文件，手动强杀进程；后续请改造应用，避免出现进程强杀失败问题"
    fi

    # 切换到应用目录
    cd "${APP_HOME}" || die 2 "应用目录不存在，请点击重试发布"

    # shellcheck disable=SC2154

COUNT=5
# pid=`ps aux | grep java | grep ${APPNAME} | grep -v grep | awk '{print $2}'`
pid=$(netstat -nlpt|grep "${APP_PORT:-8088}"|grep -v "^tcp6"|awk -F "[ /]+" '{print $7}')
if [ -z "$pid" ]; then
    # 添加异常锚点，下次捕获异常
    echo '----------------------------------------------------------'
    netstat -nlpt
    echo '----------------------------------------------------------'
    die 0 "process not found and nothing to do"
fi

RESULT=$(curl --max-time ${APP_STOP_CONNECT_TIMEOUT:-90} -s http://127.0.0.1:${APP_PORT}/ok.htm?down=true)
echo "prehalt called with result $RESULT and wait 8 seconds before real kill"
STARTTIME=$(date +"%s")
sleep 5
kill "${pid}"
while true
do
    if [ ${COUNT} -ge 25 ]; then
        echo "[DragonSystem] [stop.sh] [running] [应用30s还未关闭成功，它还活着，即将执行'kill -9 ${pid}'，进行强杀]"
        if [ -f "/var/tmp/$APPNAME.pid" ];then
            o_pid=$(cat "/var/tmp/$APPNAME.pid")
            kill -9 "${o_pid}" || die 701 "强杀进程PID=$o_pid失败，请上服务器使用tdops用户执行${TEXT_RELEASE_APP_PORT}，手动强杀进程；后续请改造应用，避免出现这种问题"
            rm -fr "/var/tmp/$APPNAME.pid" || die 2 "删除/var/tmp/$APPNAME.pid进程文件失败,请上服务器使用tdops用户删除此文件，手动强杀进程；后续请改造应用，避免出现进程强杀失败问题"
        else
            kill -9 "${pid}" || die 701 "强杀进程PID=$pid失败，请上服务器使用tdops用户执行${TEXT_RELEASE_APP_PORT}，手动强杀进程；后续请改造应用，避免出现这种问题"
        fi
        die 0 "应用强杀成功，请改造应用，使应用能正常被杀死！！！"
    fi

    ENDTIME=$(date +"%s")
    COSTTIME=$((ENDTIME - STARTTIME))
    # pid=`ps aux | grep java | grep ${APPNAME} | grep -v grep | awk '{print $2}'`
    pid=$(netstat -nlpt|grep "${APP_PORT:-8088}"|grep -v "^tcp6"|awk -F "[ /]+" '{print $7}')
    if [ ! -z "$pid" ]; then
        sleep 1
        COUNT=$((COUNT + 1))
        echo -n -e "\\rwait for killing: $COSTTIME seconds"
    else
        echo
        rm -fr "/var/tmp/$APPNAME.pid" || die 2 "删除/var/tmp/$APPNAME.pid进程文件失败,请上服务器使用tdops用户删除此文件，手动强杀进程；后续请改造应用，避免出现进程强杀失败问题"
        die 0 "应用进程已关闭"
    fi
done
    # It is forbidden to remove newline
    echo "[DragonSystem] [stop.sh] [success] [应用执行关闭完成]"
}

main() {
    get_app_name
    source_env
    check_env
    stop
}
