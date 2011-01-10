source ${BOOTSTRAP_DIR_LIB}/module-common.sh

echo " * updating all currently installed packages"
/usr/bin/yum -q update
