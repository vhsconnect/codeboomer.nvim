export PJ_ROOT := $(CURDIR)
export NVIM_TEST_HOME := $(PJ_ROOT)/test/vendor/nvim-test
export NVIM_LOG_FILE ?= $(PJ_ROOT)/.nvimlog

MAKEFLAGS += --no-builtin-rules

NVIM_TEST_RUNNER ?= nvim
FILTER ?= .*

.DEFAULT_GOAL := test

.PHONY: compile-tests
compile-tests:
	$(NVIM_TEST_RUNNER) -l scripts/compile-tests.lua

.PHONY: test
test: compile-tests
	LUA_PATH="$(NVIM_TEST_LUA_PATH);;" LUA_CPATH="$(NVIM_TEST_LUA_CPATH);;" \
	$(NVIM_TEST_RUNNER) -ll $(NVIM_TEST_HOME)/lua/nvim-test/busted/runner.lua \
		--helper=$(PJ_ROOT)/test/lua/preload.lua \
		--lpath="$(NVIM_TEST_HOME)/lua/?.lua;$(PJ_ROOT)/test/lua/?.lua;$(PJ_ROOT)/lua/?.lua" \
		--output=nvim-test.busted.output_handler \
		--verbose \
		--filter="$(FILTER)" \
		test/lua

	-@[ -t 0 ] && stty sane || true
