.PHONY: setup test

ENV_FILE ?= .env

# add env variables if needed
ifneq (,$(wildcard ${ENV_FILE}))
	include ${ENV_FILE}
    export
endif

export GREEN=\033[0;32m
export NOFORMAT=\033[0m

# ------------------------------------------------------------------------------
# Commands
#

default: help

#🔍 check: @ Runs all code verifications
check: check.lint check.dialyzer test

#🔍 check.dialyzer: @ Runs a static code analysis
check.dialyzer: SHELL:=/bin/bash
check.dialyzer:
	@mix check.dialyzer

#🔍 check.lint: @ Strictly runs a code formatter
check.lint: SHELL:=/bin/bash
check.lint:
	@mix check.format
	@mix check.credo

#🐳 docker.build: @ Build the fixed_gear_app docker image
docker.build:
	@cp ./devops/builder/Dockerfile ./
	@docker build ./ -t fixed_gear_app
	@rm ./Dockerfile

#🐳 docker.stop: @ Stop the fixed_gear_app docker instance
docker.stop:
	@docker stop fixed_gear_app || true

#🐳 docker.delete: @ Delete the fixed_gear_app docker instance
docker.delete:
	@docker rm fixed_gear_app || true

#🐳 docker.logs: @ Show logs for the fixed_gear_app docker instance
docker.logs:
	@docker logs fixed_gear_app -f

#🐳 docker.run: @ Run the fixed_gear_app docker instance
# macOS AirPlay Receiver often binds :5000. Override with: make docker.run PORT=5001
docker.run: PORT:=5000
docker.run:
	@docker run --detach --name fixed_gear_app --network fixed_gear_devops_storage -p ${PORT}:5000 --env-file .env.prod fixed_gear_app

#🐳 docker.connect: @ Connect to the fixed_gear_app running container
docker.connect:
	@docker exec -it fixed_gear_app /bin/bash

#🐳 docker.release: @ Re-create a docker image and run it
docker.release: PORT:=5000
docker.release: docker.stop docker.delete docker.build docker.run

#❓ help: @ Displays this message
help: SHELL:=/bin/bash
help:
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(firstword $(MAKEFILE_LIST))| tr -d '#'  | awk 'BEGIN {FS = ":.*?@ "}; {printf "${GREEN}%-30s${NOFORMAT} %s\n", $$1, $$2}'

#💻 lint: @ Formats code
lint: SHELL:=/bin/bash
lint: MIX_ENV=dev
lint:
	@mix format
	@mix check.credo

#💻 server: @ Starts a server with an interactive elixir shell.
server: SHELL:=/bin/bash
server:
	@iex -S mix phx.server

#📦 setup: @ Installs dependencies and set up database for dev and test envs
setup: SHELL:=/bin/bash
setup:
	MIX_ENV=dev mix setup
	MIX_ENV=test mix setup

#🧪 test: @ Runs all test suites
test: SHELL:=/bin/bash
test: MIX_ENV=test
test:
	@mix test

#🧪 test.watch: @ Runs and watches all test suites
test.watch: SHELL:=/bin/bash
test.watch: MIX_ENV=test
test.watch:
	@echo "Watching all test suites..."
	@mix test.watch

#🧪 test.wip.watch: @ Runs and watches test suites that match the wip tag
test.wip.watch: SHELL:=/bin/bash
test.wip.watch: MIX_ENV=test
test.wip.watch:
	@echo "Watching test suites tagged with wip..."
	@mix test.watch --only wip
