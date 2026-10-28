# Utilities to use in k8s cluster

- alpine with networking tools (nslookup, host, telnet, wget, curl, etc.)
- MariaDB/MySQL, Redis and AWS clients
- `rclone` to copy/sync between S3-compatible storages (AWS S3, MinIO, SeaweedFS) and `jq`
- extra utility scripts:
    - `browsemysql` - interactive console to browse a MariaDB or MySQL database; uses env vars `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PWD`, `MYSQL_DATABASE`
    - `browseredis` - interactive console to browse Redis cache;  uses env vars `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
    - `flushredis` - calls `flushall` on Redis cache; uses same env vars as above

## Env vars

### MariaDB/MySQL

The image ships the MariaDB client (`mariadb`, `mariadb-dump`, also callable under the deprecated `mysql`/`mysqldump` names), which works with both MariaDB and MySQL (5.7 and 8+) servers. Dumps can be moved between the two in either direction. Client defaults are in `config/alp.cnf`: TLS is off, because MySQL servers don't pass the certificate checks of recent MariaDB clients. Add `--ssl` to `MYSQL_OPTS` to use it anyway.

| Name             | Mandatory             | Default                           |
| ---------------- | --------------------- | --------------------------------- |
| `MYSQL_HOST`     |                       | `mysql.default.svc.cluster.local` |
| `MYSQL_PORT`     |                       | 3306                              |
| `MYSQL_USER`     |                       | `root`                            |
| `MYSQL_PWD`      | *either this or file* | *none*                            |
| `MYSQL_PWD_FILE` | *either this or file* | *none*                            |
| `MYSQL_DATABASE` |                       | *none*                            |
| `MYSQL_OPTS`     |                       | *none*                            |

### Redis

| Name                  | Mandatory | Default                           |
| --------------------- | --------- | --------------------------------- |
| `REDIS_HOST`          |           | `redis.default.svc.cluster.local` |
| `REDIS_PORT`          |           | 6379                              |
| `REDIS_PASSWORD`      |           | *none*                            |
| `REDIS_PASSWORD_FILE` |           | *none*                            |

### AWS

Everything from [documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html).

### rclone

`aws s3 sync` works within one endpoint. To copy between two storages (e.g. MinIO → SeaweedFS, or a cluster → AWS), use `rclone`. Remotes can be defined entirely through env vars (`RCLONE_CONFIG_<REMOTE>_<OPTION>`), so no config file is needed in the pod:

```bash
# remote "src": MinIO in the cluster
export RCLONE_CONFIG_SRC_TYPE=s3
export RCLONE_CONFIG_SRC_PROVIDER=Minio
export RCLONE_CONFIG_SRC_ENDPOINT=http://minio.minio.svc.cluster.local:9000
export RCLONE_CONFIG_SRC_ACCESS_KEY_ID=...
export RCLONE_CONFIG_SRC_SECRET_ACCESS_KEY=...
# remote "dst": SeaweedFS (provider SeaweedFS) or AWS (provider AWS, plus RCLONE_CONFIG_DST_REGION, no endpoint)
export RCLONE_CONFIG_DST_TYPE=s3
export RCLONE_CONFIG_DST_PROVIDER=SeaweedFS
export RCLONE_CONFIG_DST_ENDPOINT=http://seaweedfs.seaweedfs.svc.cluster.local:9000
export RCLONE_CONFIG_DST_ACCESS_KEY_ID=...
export RCLONE_CONFIG_DST_SECRET_ACCESS_KEY=...

# dry run first, then copy (sync would also delete extra files on the destination)
rclone copy src:nrandprimary dst:nrandprimary --checksum --transfers 16 -P --dry-run
rclone copy src:nrandprimary dst:nrandprimary --checksum --transfers 16 -P
```


# Building & releasing

The version lives in `VERSION` (semver, without the `v` prefix of the image tag).

```bash
# local build, tagged csabasulyok/alp:v<VERSION> and :latest
./build
```

GitHub Actions (`.github/workflows/ci.yml`) builds the image on every push. On `master` it also pushes `csabasulyok/alp:v<VERSION>` and `csabasulyok/alp:latest` to Docker Hub. It fails if `v<VERSION>` already exists, so bump `VERSION` on every branch.

The push logs in as `csabasulyok` with the repository secret `DOCKER_PASSWORD` (GitHub repo *Settings → Secrets and variables → Actions*), a Docker Hub personal access token with *Read & Write* scope.

# Setting up in k8s

## One-off pod

Good for a quick look; the pod is removed when the shell exits, and anything running in it dies with it.

```bash
# bash
kubectl run alp -it --rm --image=csabasulyok/alp
# a specific internal command
kubectl run alp -it --rm --image=csabasulyok/alp --command -- browseredis
```

## Long-running StatefulSet

For anything that should stay around (env vars & secrets set up once, long syncs, repeated use), run it as a StatefulSet with a single replica instead of a bare pod. A bare pod is gone for good once it fails, is evicted or its node restarts; the StatefulSet recreates it under the same stable name, `alp-0`. The image's default command (`bash`) exits without a terminal, so the container just sleeps and you `exec` into it.

```yaml
# alp.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: alp
spec:
  replicas: 1
  serviceName: alp
  selector:
    matchLabels:
      app: alp
  template:
    metadata:
      labels:
        app: alp
    spec:
      containers:
        - name: alp
          image: csabasulyok/alp:v1.9.7
          command: ["sleep", "infinity"]
          env:
            - name: MYSQL_HOST
              value: mariadb.mariadb.svc.cluster.local
            - name: MYSQL_USER
              value: nrand
            - name: MYSQL_DATABASE
              value: nrand
            - name: MYSQL_PWD_FILE
              value: /secrets/mariadb-secrets/password
          volumeMounts:
            - name: mariadb-secrets
              mountPath: /secrets/mariadb-secrets
              readOnly: true
      volumes:
        - name: mariadb-secrets
          secret:
            secretName: mariadb-secrets
```

```bash
kubectl apply -f alp.yaml
# run bash
kubectl exec -it alp-0 -- bash
# run specific task
kubectl exec -it alp-0 -- browsemysql
# remove when no longer needed
kubectl delete -f alp.yaml
```

A job started in an `exec` session dies when that session closes. Start long jobs (e.g. an `rclone copy`) in the background so they outlive it, and follow the log instead:

```bash
kubectl exec alp-0 -- sh -c 'nohup rclone copy src:nrandprimary dst:nrandprimary --checksum > /tmp/rclone.log 2>&1 &'
kubectl exec -it alp-0 -- tail -f /tmp/rclone.log
```

For this, define the `RCLONE_CONFIG_*` remotes in the StatefulSet's `env` rather than exporting them in an interactive shell. Jobs still stop if the pod itself restarts. Re-running is safe, since `rclone copy` skips files that are already there.
