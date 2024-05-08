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
    echo "[DragonSystem] [validate.sh] [$result] [${msg}]" && exit "${code}"
}

USER_HOME=/home/admin
APP_HOME="${USER_HOME}/${APPNAME}"
if [ "${APP_RUN_MODE}" != "fg" ] && [ "${MULTIPLE_TRUNK_DEPLOY}" = "true" ] && [ "${CHECKOUT_FROM}" != "master" ]
then
    APP_HOME=/home/admin/${APPNAME}-${CHECKOUT_FROM}
fi
TRAFFIC_SWITCH=$2
APP_PORT_INPUT=$1

TEXT_CICD_TEAM="请联系容器云团队"
# shellcheck disable=SC2034
TEXT_FILE_NOT_EXIST="文件不存在，${TEXT_CICD_TEAM}"
# shellcheck disable=SC2034
TEXT_FAILED=" failed..."
# shellcheck disable=SC2034
TEXT_RELEASE_APP_PORT="sudo netstat -nlpt|grep ${APP_PORT:-8088}|awk -F \"[ /]+\" '{print $7}'|xargs kill -9"

source_env() {
    echo "[DragonSystem] [validate.sh] [begin] [应用开始进行健康检查]"
    if [ -f "${APP_HOME}/env.sh" ]; then
        # shellcheck source=/home/admin/$APPNAME/env.sh
        # shellcheck disable=SC1091
        . "${APP_HOME}/env.sh" || die 501 "source env.sh params error!"
    fi
}

init() {
    if [ -z "${APP_PORT}" ]; then
        APP_PORT="${APP_PORT_INPUT}"
        export APP_PORT="${APP_PORT}"
    fi
}

# append user validate.sh content
check_ok() {
    # 切换到应用目录
    cd "${APP_HOME}" || die 2 "应用目录不存在，请点击重试发布"

    # shellcheck disable=SC2154

SERVER_SERVLET_PATH=/api

if [ -z ${APP_PORT} ];
then
    if [ -f application.port ];
    then
        APP_PORT=$(cat application.port)
    else
        echo "application.port文件不存在"
        exit 1
    fi
fi

http_code=$(curl --connect-timeout 1 -I -m 1 -o /dev/null -s -w "%{http_code}" http://127.0.0.1:${APP_PORT}${SERVER_SERVLET_PATH}/ok)

if [ "$http_code" = "200" ]; then
    exit 0
fi

echo "ok页面访问不通"
exit 1

     # It is forbidden to remove newline
}

# check traffic switch if $2 not zero
check_traffic_switch() {
    if [ ! -z "${TRAFFIC_SWITCH}" ]; then
        ls ${USER_HOME}/.traffic_switch > /dev/null 2>&1 || die 602 "Closed traffic switch"
        echo "traffic switch opening"
    fi
    echo "[DragonSystem] [validate.sh] [success] [应用健康检查完成，恭喜，您的应用非常健康]"
}

main() {
    source_env
    init
    check_ok
    check_traffic_switch
}