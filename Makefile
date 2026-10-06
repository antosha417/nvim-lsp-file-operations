.PHONY: all clean format help lint test test-all

all: help

clean: ## Clean auto-generated artifacts
	@rm -rf .test-deps

format: .stylua.toml ## Format using StyLua
	@stylua .

help: ## Print this help message
	@echo -e "Usage: make [target]\n\nAvailable targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

lint: selene.toml ## Lint Lua files with selene
	@selene .

test: ## Test against the current Neovim version
	@busted

test-all: ## Test against different Neovim versions
	@./scripts/test-all.sh
