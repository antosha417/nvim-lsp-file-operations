# nvim-lsp-file-operations

`nvim-lsp-file-operations` is a Neovim plugin that adds support for file operations using built-in [LSP
support](https://neovim.io/doc/user/lsp.html).
This plugin works by subscribing to events emitted by [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua).
But other integrations are possible.

## Installation
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'antosh417/nvim-lsp-file-operations',
  requires = {
    { "davidm/lua-glob-pattern" },
    { "nvim-lua/plenary.nvim" },
    { "kyazdani42/nvim-tree.lua" },
  }
}
```

## Setup
```lua
require("lsp-file-operations").setup()
```
This is equivalent to:
```lua
require("lsp-file-operations").setup {
  -- used to see debug logs in file `vim.fn.stdpath("cache") .. lsp-file-operations.log`
  debug = false
}
```

## Features
Currently only `workspace/WillRename`

## Contributing
PRs are always welcome.

