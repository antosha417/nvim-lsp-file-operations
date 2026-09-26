# nvim-lsp-file-operations

`nvim-lsp-file-operations` is a Neovim plugin that adds support for file operations using [built-in LSP support](https://neovim.io/doc/user/lsp/).

This plugin works by subscribing to events emitted by either of these plugins
(other integrations may be added if needed):

- [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [nvim-tree/nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
- [simonmclean/triptych.nvim](https://github.com/simonmclean/triptych.nvim)

<https://user-images.githubusercontent.com/14187674/211327507-39f21a74-0a43-43f0-ba3e-91109125286c.mp4>

---

## Features

Full implementation of all `workspace.fileOperations` for [the current LSP spec](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/):

- [`workspace/DidCreate`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_didCreateFiles)
- [`workspace/DidDelete`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_didDeleteFiles)
- [`workspace/DidRename`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_didRenameFiles) - Tested in:
  - [lua-language-server](https://github.com/LuaLS/lua-language-server)
  - [vtsls](https://github.com/yioneko/vtsls)
- [`workspace/WillCreate`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_willCreateFiles)
- [`workspace/WillDelete`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_willDeleteFiles)
- [`workspace/WillRename`](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_willRenameFiles) - Tested in:
  - [basedpyright](https://docs.basedpyright.com/latest)
  - [metals](https://scalameta.org/metals/)
  - [rust-analyzer](https://rust-analyzer.github.io/)
  - [typescript-language-server](https://github.com/typescript-language-server/typescript-language-server)

**If you have use cases for any other operations please open an issue.**

---

## Table of Contents

- [Installation](#installation)
- [Setup](#setup)
  - [LSP Capabilities](#lsp-capabilities)
- [Contributing](#contributing)
- [License](#license)

---

## Installation

> [!IMPORTANT]
> **The order in which the plugins are loaded matters!**
>
> For example, `neo-tree.nvim` must load before `nvim-lsp-file-operations` for this to work,
> so `nvim-lsp-file-operations` depends on `neo-tree.nvim`, not the other way around!

<details>
<summary>Using <a href="https://github.com/lewis6991/pckr.nvim">pckr.nvim</a></summary>

```lua
require("pckr").add({
  "antosha417/nvim-lsp-file-operations",
  -- Uncomment whichever supported plugin(s) you use
  -- requires = {
  --   "nvim-tree/nvim-tree.lua",
  --   "nvim-neo-tree/neo-tree.nvim",
  --   "simonmclean/triptych.nvim"
  -- },
  config = function()
    require("lsp-file-operations").setup()
  end,
})
```

</details>
<details>
<summary>Using <a href="https://github.com/folke.lazy.nvim">lazy.nvim</a></summary>

```lua
return {
  {
    "antosha417/nvim-lsp-file-operations",
    -- Uncomment whichever supported plugin(s) you use
    -- dependencies = {
    --   "nvim-tree/nvim-tree.lua",
    --   "nvim-neo-tree/neo-tree.nvim",
    --   "simonmclean/triptych.nvim"
    -- },
    config = function()
      require("lsp-file-operations").setup()
    end,
  },
}
```

</details>

---

## Setup

Simply call:

```lua
require("lsp-file-operations").setup()
```

The default options are:

```lua
{
  -- If `true`, allows the plugin to handle auto-saving after making LSP operations
  auto_save = false,

  -- Used to see debug logs, located at `vim.fn.stdpath("cache") .. "/lsp-file-operations.log"`
  debug = false,

  -- Select which file operations to enable
  operations = {
    didCreateFiles = true,
    didDeleteFiles = true,
    didRenameFiles = true,
    willCreateFiles = true,
    willDeleteFiles = true,
    willRenameFiles = true,
  },

  -- How long to wait (in milliseconds) for file rename information before cancelling
  timeout_ms = 10000,
}
```

### LSP Capabilities

Some LSP servers also expect to be informed about the extended client capabilities.
Follow any of the instructions below based on your Neovim version:

<details>
<summary>Neovim <code>v0.11</code> or later</summary>

You can use `vim.lsp.config()` to set the global capabilities for every server:

```lua
-- Set global defaults for all servers
vim.lsp.config("*", {
  capabilities = vim.tbl_deep_extend(
    "force",
    vim.lsp.protocol.make_client_capabilities(),
    -- ANY OTHER CAPABILITIES. e.g. for `blink.cmp`, etc.
    require("lsp-file-operations").default_capabilities()
  )
})
```

</details>
<details>
<summary>Neovim older than <code>v0.11</code></summary>

If you use [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) you can configure the default client capabilities for all servers:

```lua
local lspconfig = require("lspconfig")

-- Set global defaults for all servers
lspconfig.util.default_config = vim.tbl_extend(
  "force",
  lspconfig.util.default_config,
  {
    capabilities = vim.tbl_deep_extend(
      "force",
      vim.lsp.protocol.make_client_capabilities(),
      -- ANY OTHER CAPABILITIES. e.g. for `blink.cmp`, etc.
      require("lsp-file-operations").default_capabilities()
    )
  }
)
```

</details>

---

## Contributing

PRs are always welcome.

This project uses [StyLua](https://github.com/JohnnyMorganz/StyLua). Please run `stylua .` before committing.

---

## License

[Apache-2.0](https://github.com/antosha417/nvim-lsp-file-operations/blob/master/LICENSE)
