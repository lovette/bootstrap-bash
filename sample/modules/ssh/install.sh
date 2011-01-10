source ${BOOTSTRAP_DIR_LIB}/module-common.sh
source ${BOOTSTRAP_DIR_LIB}/file.sh

# Backup distribution configuration for reference
bootstrap_file_move /etc/ssh/sshd_config /etc/ssh/sshd_config-dist "" 0 0

bootstrap_file_copy "${BOOTSTRAP_DIR_MODULE}/files/sshd_config" /etc/ssh/sshd_config "root:root" 644 1
