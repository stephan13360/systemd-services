#!/bin/bash

set -e
set -u
set -o pipefail

_info(){
    echo "$@"
}

_err() {
    _info "$@"
    exit 1
}

_main() {
    _info "Create Postgres Dump of all Databases"

    DBS=$(psql -t -A -c 'SELECT datname FROM pg_database' | grep -P -v '(template0|template1|postgres)')

    for DB in $DBS; do
        pg_dump -Fc "$DB" -f /backup/postgres-"$DB".pg_dump 2>/backup/pg_dump.log; OUT=$?
        if test $OUT -eq 0; then
            _info "Postgres Dump of $DB successful"
        else
            _err "Postgres Dump $DB had problems, pg_dump statuscode = $OUT"
        fi
    done

    _info "Postgres Dump of all Databases successful"
}

_main
