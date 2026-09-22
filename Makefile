.PHONY: test test-all format

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

test-all:
	./scripts/test-all.sh

format:
	stylua .
