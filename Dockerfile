# start from alpine
FROM alpine:3.24

# add bash, curl, wget, other networking tools, MariaDB/MySQL, Redis & AWS clients
#   mariadb-connector-c provides the auth plugins needed for MySQL 8+ (caching_sha2_password)
#   rclone syncs between S3-compatible storages (AWS, MinIO, SeaweedFS)
RUN apk add --no-cache bash bind-tools curl wget busybox-extras redis mariadb-client mariadb-connector-c aws-cli python3 rclone jq

# MariaDB/MySQL client defaults
COPY config/alp.cnf /etc/my.cnf.d/alp.cnf

# copy utilities and add to PATH
COPY utils/ /utils/
ENV PATH="/utils:${PATH}"

# start with bash
CMD ["/bin/bash"]
