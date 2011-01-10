source ${BOOTSTRAP_DIR_LIB}/module-common.sh
source ${BOOTSTRAP_DIR_LIB}/file.sh

# Backup distribution configuration for reference
bootstrap_file_move /etc/sysconfig/mongod /etc/sysconfig/mongod-dist "" 0 0

bootstrap_file_copy "${BOOTSTRAP_DIR_MODULE}/files/sysconfig.conf" /etc/sysconfig/mongod "root:root" 644 1

# Add mongodb listening ports to services so netstat can decode them
if ! grep -q 27017 /etc/services; then
	echo " * adding custom ports to /etc/services"
	echo "mongod 27017/tcp" >> /etc/services
	echo "mongod-websvr 28017/tcp" >> /etc/services
fi
