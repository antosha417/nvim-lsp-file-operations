# nvim-lsp-file-operations

`nvim-lsp-file-operations` is a Neovim plugin that adds support for file operations using built-in [LSP
support](https://neovim.io/doc/user/lsp.html).
This plugin works by subscribing to events emitted by [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua), [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) and [triptych](https://github.com/simonmclean/triptych.nvim). But other integrations are possible.

## Features

Full implementation of all [`workspace.fileOperations`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/) in the current lsp spec:

- [workspace/WillRename](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_willRenameFiles) (Currently tested with [metals](https://scalameta.org/metals/), [rust-analyzer](https://rust-analyzer.github.io/) and [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server))
- [workspace/DidRename](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_didRenameFiles) (Currently tested with [vtsls](https://github.com/yioneko/vtsls) and [lua-language-server](https://github.com/LuaLS/lua-language-server))
- [workspace/WillCreate](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_willCreateFiles)
- [workspace/DidCreate](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_didCreateFiles)
- [workspace/WillDelete](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_willDeleteFiles)
- [workspace/DidDelete](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_didDeleteFiles)

https://user-images.githubusercontent.com/14187674/211327507-39f21a74-0a43-43f0-ba3e-91109125286c.mp4

**If you have usecases for any other operations please open an issue.**

## Installation

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "antosha417/nvim-lsp-file-operations",
  requires = {
    "nvim-lua/plenary.nvim",
    -- Uncomment whichever supported plugin(s) you use
    -- "nvim-tree/nvim-tree.lua",
    -- "nvim-neo-tree/neo-tree.nvim",
    -- "simonmclean/triptych.nvim"
  },
  config = function()
    require("lsp-file-operations").setup()
  end,
}
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Note that the config function will let you skip the setup step.

```lua
return {
  {
    "antosha417/nvim-lsp-file-operations",
    dependencies = {
      "nvim-lua/plenary.nvim",
    -- Uncomment whichever supported plugin(s) you use
    -- "nvim-tree/nvim-tree.lua",
    -- "nvim-neo-tree/neo-tree.nvim",
    -- "simonmclean/triptych.nvim"
    },
    config = function()
      require("lsp-file-operations").setup()
    end,
  },
}
```

Please note that the order that the plugins load in is important, neo-tree must load before
nvim-lsp-file-operations for it to work, so nvim-lsp-file-operations depends on neo-tree and not the other way
around.

## Setup

```lua
require("lsp-file-operations").setup()
```

This is equivalent to:

```lua
require("lsp-file-operations").setup {
  -- used to see debug logs in file `vim.fn.stdpath("cache") .. lsp-file-operations.log`
  debug = false,
  -- select which file operations to enable
  operations = {
    willRenameFiles = true,
    didRenameFiles = true,
    willCreateFiles = true,
    didCreateFiles = true,
    willDeleteFiles = true,
    didDeleteFiles = true,
  },
  -- how long to wait (in milliseconds) for file rename information before cancelling
  timeout_ms = 10000,
}
```
Some LSP servers also expect to be informed about the extended client capabilities.
If you use [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) you can configure the default client capabilities that will
be sent to all servers like this:

```lua
local lspconfig = require'lspconfig'

-- Set global defaults for all servers
lspconfig.util.default_config = vim.tbl_extend(
  'force',
  lspconfig.util.default_config,
  {
    capabilities = vim.tbl_deep_extend(
      "force",
      vim.lsp.protocol.make_client_capabilities(),
      -- returns configured operations if setup() was already called
      -- or default operations if not
      require'lsp-file-operations'.default_capabilities(),
    )
  }
)
```

## Contributing

PRs are always welcome.
