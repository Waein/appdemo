#!/bin/bash

die() {
    if [ $# != 2 ] ; then
        echo " The first is return code,the second error message!"
        echo " e.g.: die 1 'error message'"
        exit 1;
    fi
    code=$1
    msg=$2
    echo "${msg}" && exit "${code}"
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

source_env() {
    echo "[DragonSystem] [prestop.sh] [begin] [优雅停应用(进行流量摘除和自定义停应用前操作)检查开始]"
    if [ -f "${APP_HOME}/env.sh" ]; then
        # shellcheck source=/home/admin/$APPNAME/env.sh
        # shellcheck disable=SC1091
        . "${APP_HOME}/env.sh" || die 501 "source env.sh params error!"
    fi
}

traffic_switch() {
    if [ "${APP_RUN_MODE}" = "fg" ] || [ "${APP_RUN_MODE}" = "mix" ]; then
        if [ ! -f ${USER_HOME}/.traffic_switch ]; then
            die 801, "${USER_HOME}/.traffic_switch file does not exist"
        fi
        # 设置流量标识，切断流量
        rm -f ${USER_HOME}/.traffic_switch
        echo "[DragonSystem] [prestop.sh] [running]] [应用优雅停止之成功删除流量接入标识]]"
    fi
}

pre_stop() {
    # 切换流量
    traffic_switch

    # 阻塞15s，等待readness生命周期结束
    sleep 15

    # append user prestop.sh content
    # shellcheck disable=SC2154

if [ "${APP_RUN_MODE}" = "fg" ];then
    echo "prehalt called and wait 8 seconds before real kill"
    curl --connect-timeout 8 -s http://127.0.0.1:${APP_PORT}/ok.htm?down=true
fi    # It is forbidden to remove newline
    echo "[DragonSystem] [prestop.sh] [success] [应用优雅停应用]"
}

main() {
    source_env
    pre_stop
}