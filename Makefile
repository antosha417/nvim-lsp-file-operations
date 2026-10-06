.PHONY: all clean format help test test-all

all: help

clean: ## Clean auto-generated artifacts
	@rm -rf .test-deps

format: ## Format using StyLua
	@stylua .

help: ## Print this help message
	@echo -e "Usage: make [target]\n\nAvailable targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

test: ## Test against the current Neovim version using busted
	@busted

test-all: ## Test against different Neovim versions using busted
	@./scripts/test-all.sh
