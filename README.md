# nvim-lsp-file-operations

`nvim-lsp-file-operations` is a Neovim plugin that adds support for file operations using built-in [LSP
support](https://neovim.io/doc/user/lsp.html).
This plugin works by subscribing to events emitted by [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua).
But other integrations are possible.


## Features
* [workspace/WillRename](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_willRenameFiles)

WillRename requests supported in couple lsp-servers and allows to automagically apply some refactorings while you moving files around. Currently tested with [metals](https://scalameta.org/metals/) and [rust-analyzer](https://rust-analyzer.github.io/).


https://user-images.githubusercontent.com/14187674/211327507-39f21a74-0a43-43f0-ba3e-91109125286c.mp4


**If you have usecases for any other operations please open an issue.**

## Installation
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'antosh417/nvim-lsp-file-operations',
  requires = {
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

## Contributing
PRs are always welcome.

