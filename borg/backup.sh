#!/bin/bash

set -e
set -u
set -o pipefail

_mail() {
    mail -s "$SUBJECT" "$EMAIL" < "$EMAILMESSAGE"
}

_infomail() {
    SUBJECT="borgbackup on $THISHOST finished successfully"
    _mail
}

_info(){
    echo "$@" | tee -a "$EMAILMESSAGE"
}

_err() {
    _info "$@"
    SUBJECT="ERROR during backup on $THISHOST"
    _mail
    exit 1
}

_init() {
    THISHOST={{ inventory_hostname }}
    EMAIL="{{ backup_mail }}"
    EMAILMESSAGE="/tmp/emailmessage.txt"

    REPOSITORY="{{ backup_repo }}"
    BACKUPPFADE="{{ backup_paths }}"
}

_main() {
    _init
    _create
    _check
    _prune
    _infomail
}

_create() {
    _info "Running borg create"

    borg create -v --stats --compression lz4 "$REPOSITORY::$THISHOST-$(date +%Y-%m-%d-%R)" $BACKUPPFADE 1>>"$EMAILMESSAGE" 2>>"$EMAILMESSAGE"; OUT=$?

    if test $OUT -eq 0; then
        _info "borg create successful"
        date > /backup.last
    else
        _err "borg create had problems, borg statuscode = $OUT"
    fi
}

_check() {
    _info "Running borg check"

    borg check -v "$REPOSITORY"; OUT=$?

    if test $OUT -eq 0; then
        _info "borg check successful"
    else
        _err "borg check had problems, borg statuscode = $OUT"
    fi
}

_prune() {
    _info "Running borg prune"

    borg prune -v --list "$REPOSITORY" --prefix "$THISHOST"- --keep-daily=30 --keep-weekly=12 --keep-monthly=12 1>>"$EMAILMESSAGE" 2>>"$EMAILMESSAGE"; OUT=$?

    if test $OUT -eq 0; then
        _info "borg prune successful"
    else
        _err "borg prune had problems, borg statuscode = $OUT"
    fi
}

_main
