.PHONY: test test-all format clean all

all: test-all

clean:
	@rm -rf .test-deps

test:
	@busted

test-all:
	@./scripts/test-all.sh

format:
	@stylua .
