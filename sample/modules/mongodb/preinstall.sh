source ${BOOTSTRAP_DIR_LIB}/file.sh
source ${BOOTSTRAP_DIR_LIB}/users.sh

# Add user account before the package is installed so we can control the UID
bootstrap_user_add_system "100" "mongod" "MongoDB" "/var/lib/mongo"
