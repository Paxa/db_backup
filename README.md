# db_backup - Container friendly backup for databases

_early alpha, don't use it_

### Supported databases:

* Postgres (pg_dump)
* Influxdb (influxd backup)
* Local File

### Supported storages:

* Local Folder
* Backblaze (via pip b2)
* WebDav (via curl)

### Example:

Basic:

```sh
./bin/db_backup backup \
  --verbose \
  --source postgres://postgres@localhost/my_app \
  --taget b2://key:token@bucket/path \
  --keep-num 5

```

With enviroment variables:

```sh
export BACKUP_VERBOSE=1
export BACKUP_SOURCE=postgres://postgres@localhost/my_app
export BACKUP_TARGET=b2://key:token@bucket/path
export BACKUP_KEEP_NUM=5
./bin/db_backup backup
```

### Docker image

```
evpavel/db_backup
```

https://hub.docker.com/r/evpavel/db_backup/
