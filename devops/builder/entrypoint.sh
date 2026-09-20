#!/usr/bin/env bash

bin="bin/fixed_gear"

hello() {
  set -e

  # Simple application interaction
 $bin eval "IO.puts(FixedGear.hello())"
}

create_db() {
  set -e

  echo ======== Create DB ========
  $bin eval "FixedGear.Release.create_db()"
}

migrate() {
  set -e

  echo ======== Starting ecto migration ========
  $bin eval "FixedGear.Release.migrate()"
}

seeds() {
  set -e

  echo ======== Creating seeds ========
  $bin eval "FixedGear.Release.seed()"
}

setup_db() {
  set -e

  echo Setting up DB...
  # Run the create db
  create_db
  # Run the migrate script
  migrate
  # Run seeds creation
  seeds
}

start() {
  set -e

  # Run the setup_db script
  setup_db

  echo ======== Starting fixed_gear ========
  $bin start
}

case $1 in
  hello) "$@"; exit;;
  create_db) "$@"; exit;;
  migrate) "$@"; exit;;
  seeds) "$@"; exit;;
  setup_db) "$@"; exit;;
  start) "$@"; exit;;
esac
