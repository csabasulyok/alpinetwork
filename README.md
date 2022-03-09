# Utilities to use in k8s cluster

- alpine with networking tools (nslookup, host, telnet, wget, curl, etc.)
- MySQL, Redis and AWS clients
- extra utility scripts:
    - `browsemysql` - interactive console to browse MySQL database; uses env vars `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USERNAME`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`
    - `browseredis` - interactive console to browse Redis cache;  uses env vars `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
    - `flushredis` - calls `flushall` on Redis cache; uses same env vars as above

## Env vars

### MySQL

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


# Building

```bash
# build
docker build -t csabasulyok/alp:v1.9.6 .
# push
docker login
docker push csabasulyok/alp:v1.9.6
```

# Setting up in k8s

## Running dry

```bash
# run with bash, will be removed after closing
kubectl run -it --rm --image=csabasulyok/alp -- alp
# run specific internal command
kubectl run -it --rm --image=csabasulyok/alp --command=true -- alp browseredis
```

## Create pod in advance (easier for setting env vars)

```bash
# create pod in advance using k8s manifest
# run bash
kubectl exec -it alp -- bash
# run specific task
kubectl exec -it alp -- browseredis
```