#!/bin/bash
set -e

PLATFORMTYPE=AKYLIN
RUNTIME_FILE_NAME=platform_runtime_AKYLIN_UB18_x64_service
TOP_INSTALL_DIR=/opt/tobiipdk/AKYLIN
BIN_INSTALL_DIR=/opt/tobiipdk/AKYLIN/bin
LIB_INSTALL_DIR=/opt/tobiipdk/AKYLIN/lib
SYSTEMD_SERVICE_FILE_NAME=tobii-runtime-AKYLIN.service
SERVICE_FILE_DEST=/etc/systemd/system

function detect_init_system
{
    if [ -d /run/systemd/system ]; then echo SYSTEMD;
    elif [[ `/sbin/init --version` =~ upstart ]]; then echo UPSTART;
    elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then echo SYSVINIT;
    else echo UNKNOWN
    fi
}

# $1: Name of service file
function systemd_stop_and_disable_service
{
    if systemctl is-active --quiet $1; then
        echo "I: Stopping service $1"
        systemctl stop --quiet $1
    fi

    if [ -f ${SERVICE_FILE_DEST}/${SYSTEMD_SERVICE_FILE_NAME} ]; then
        if systemctl is-enabled --quiet $1; then
            echo "I: Disabling service $1"
            systemctl disable --quiet $1
        fi
    fi
}

function systemd_do_install
{
    systemd_stop_and_disable_service ${SYSTEMD_SERVICE_FILE_NAME}
    mkdir -p ${BIN_INSTALL_DIR}

    echo "I: Installing ${RUNTIME_FILE_NAME} to ${BIN_INSTALL_DIR}"
    install -m 755 -g root -o root bin/${RUNTIME_FILE_NAME} ${BIN_INSTALL_DIR}

    if [ -f lib/libinference_engine.so ]; then
        mkdir -p ${LIB_INSTALL_DIR}

        echo "I: Installing libraries to ${LIB_INSTALL_DIR}"
        install -m 644 -g root -o root lib/*.so lib/*.so.* ${LIB_INSTALL_DIR}
    fi

    echo "I: Installing ${SYSTEMD_SERVICE_FILE_NAME} to ${SERVICE_FILE_DEST}"
    install -m 644 -g root -o root systemd/${SYSTEMD_SERVICE_FILE_NAME} ${SERVICE_FILE_DEST}

    echo "I: Starting ${SYSTEMD_SERVICE_FILE_NAME}"
    systemctl start  ${SYSTEMD_SERVICE_FILE_NAME}
    systemctl enable ${SYSTEMD_SERVICE_FILE_NAME}
}

function systemd_do_uninstall
{
    systemd_stop_and_disable_service ${SYSTEMD_SERVICE_FILE_NAME}

    if [ -f ${SERVICE_FILE_DEST}/${SYSTEMD_SERVICE_FILE_NAME} ]; then
        echo "I: Removing ${SERVICE_FILE_DEST}/${SYSTEMD_SERVICE_FILE_NAME}"
        rm -rf ${SERVICE_FILE_DEST}/${SYSTEMD_SERVICE_FILE_NAME}
    fi

    if [ -d ${TOP_INSTALL_DIR} ]; then
        echo "I: Removing ${TOP_INSTALL_DIR}"
        rm -rf ${TOP_INSTALL_DIR}
    fi
}


#
# Script start
#
INIT_SYSTEM=$(detect_init_system)
if [ "${INIT_SYSTEM}" != "SYSTEMD" ]; then
    echo "E: Your init system (${INIT_SYSTEM}) is not supported"
    exit 1
fi


case $1 in
    "--install")
        if [ ${INIT_SYSTEM} == SYSTEMD ]; then
            systemd_do_install
        fi
        ;;

    "--uninstall")
        if [ ${INIT_SYSTEM} == SYSTEMD ]; then
            systemd_do_uninstall
        fi
        ;;

    *)
        echo "Unsupported option: $1"
        exit 1
esac
