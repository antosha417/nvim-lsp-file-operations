---@module "lsp-file-operations._meta"

local Utils = require("lsp-file-operations.utils")
local Log = require("lsp-file-operations.log")

local default_config = { ---@type LspFileOpsConfig
  auto_save = false,
  debug = false,
  operations = {
    didCreateFiles = true,
    didDeleteFiles = true,
    didRenameFiles = true,
    willCreateFiles = true,
    willDeleteFiles = true,
    willRenameFiles = true,
  },
  timeout_ms = 10000,
}

local config = nil ---@type LspFileOpsConfig|nil|?

---Safely writes a specific buffer to disk if it has unsaved mutations
---
---Sourced from `nvim-file-operations`, all credits go to @Crysthamus.
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations/autosave.lua
---@type fun(uris: string[])
local save_buffers = vim.schedule_wrap(function(uris) ---@param uris string[]
  Utils.validate({ uris = { uris, { "table" } } })

  for _, uri in ipairs(uris) do
    local bufnr = vim.uri_to_bufnr(uri)
    if
      vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_buf_is_loaded(bufnr)
      and vim.api.nvim_get_option_value("modified", { buf = bufnr })
    then
      vim.api.nvim_buf_call(bufnr, function()
        if pcall(vim.cmd.update, { mods = { silent = true } }) then
          Log.debug("Successfully auto-saved buffer", bufnr, "after file operation")
          vim.cmd.checktime()
        end
      end)
    end
  end
end)

---Parses an incoming LSP WorkspaceEdit structure and extracts modified files
---
---Sourced from `nvim-file-operations`, all credits go to @Crysthamus.
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations/autosave.lua
---@param workspace_edit lsp.WorkspaceEdit The standard LSP WorkspaceEdit object payload
---@return string[] uris Array of unique URIs
local function extract_uris(workspace_edit)
  Utils.validate({ workspace_edit = { workspace_edit, { "table" } } })

  local uris = {} ---@type string[]
  if not workspace_edit then
    return uris
  end

  if workspace_edit.changes then
    for uri in pairs(workspace_edit.changes) do
      table.insert(uris, uri)
    end
  end
  if workspace_edit.documentChanges then
    for _, change in ipairs(workspace_edit.documentChanges) do
      if change.textDocument and change.textDocument.uri then
        table.insert(uris, change.textDocument.uri)
      end
    end
  end
  return Utils.dedup(uris)
end

--- helper function to subscribe events to a given module callback
---@param op_events LspFileOpsEvents the table that maps modules to event strings
---@param subscribe fun(module: string, event: string) the function for how to subscribe a module to an event
local function setup_events(op_events, subscribe)
  Utils.validate({
    op_events = { op_events, { "table" } },
    subscribe = { subscribe, { "function" } },
  })

  if not config then
    return
  end

  local modules = { ---@type table<LspFileOpsConfig.Operations, string>
    didCreateFiles = "lsp-file-operations.did-create",
    didDeleteFiles = "lsp-file-operations.did-delete",
    didRenameFiles = "lsp-file-operations.did-rename",
    willCreateFiles = "lsp-file-operations.will-create",
    willDeleteFiles = "lsp-file-operations.will-delete",
    willRenameFiles = "lsp-file-operations.will-rename",
  }
  for operation, enabled in pairs(config.operations) do
    ---@cast operation LspFileOps.Operations
    ---@cast enabled boolean
    if enabled and modules[operation] and op_events[operation] then
      vim.tbl_map(function(event) ---@param event string
        subscribe(modules[operation], event)
        return event -- NOTE: This is just to avoid an LSP warning, not used at all
      end, op_events[operation])
    end
  end
end

---@class LspFileOps.Config
local M = {}

---@return LspFileOpsConfig default_config
function M.get_defaults()
  return default_config
end

---@return LspFileOpsConfig config
function M.get()
  return config
end

---@param cfg? LspFileOpsConfig
function M.set(cfg)
  config = cfg
  Log.debug("Config modified to", config)
end

---@param opts? LspFileOpsConfig
function M.setup(opts)
  Utils.validate({ opts = { opts, { "table", "nil" }, true } })
  opts = opts or {}

  Utils.validate({
    ["opts.auto_save"] = { opts.auto_save, { "boolean", "nil" }, true },
    ["opts.debug"] = { opts.debug, { "boolean", "nil" }, true },
    ["opts.operations"] = { opts.operations, { "table", "nil" }, true },
    ["opts.timeout_ms"] = { opts.timeout_ms, { "number", "nil" }, true },
  })

  config = vim.tbl_deep_extend("force", default_config, opts)

  if config.debug then
    Log.level = "debug"
  end

  local ok_nvim_tree, nvim_tree_api = pcall(require, "nvim-tree.api")
  if ok_nvim_tree and nvim_tree_api then -- nvim-tree integration
    Log.debug("Setting up nvim-tree integration")

    local ev = nvim_tree_api.events.Event
    setup_events({
      didCreateFiles = { ev.FileCreated, ev.FolderCreated },
      didDeleteFiles = { ev.FileRemoved, ev.FolderRemoved },
      didRenameFiles = { ev.NodeRenamed },
      willCreateFiles = { ev.WillCreateFile },
      willDeleteFiles = { ev.WillRemoveFile },
      willRenameFiles = { ev.WillRenameNode },
    }, function(module, event)
      nvim_tree_api.events.subscribe(
        event,
        function(args) ---@param args { fname: string }|{ new_name: string, old_name: string }
          local ok, mod = pcall(require, module) ---@type boolean, LspFileOps.AllModules|nil|?
          if ok and mod then
            mod(args)
          end
        end
      )
    end)
  end

  local ok_neo_tree, neo_tree_events = pcall(require, "neo-tree.events")
  if ok_neo_tree and neo_tree_events then -- neo-tree integration
    Log.debug("Setting up neo-tree integration")

    setup_events({
      didCreateFiles = { neo_tree_events.FILE_ADDED },
      didDeleteFiles = { neo_tree_events.FILE_DELETED },
      didRenameFiles = { neo_tree_events.FILE_RENAMED, neo_tree_events.FILE_MOVED },
      willCreateFiles = { neo_tree_events.BEFORE_FILE_ADD },
      willDeleteFiles = { neo_tree_events.BEFORE_FILE_DELETE },
      willRenameFiles = { neo_tree_events.BEFORE_FILE_RENAME, neo_tree_events.BEFORE_FILE_MOVE },
    }, function(module, event)
      local sub_args = { ---@type neotree.event.Handler
        id = ("%s.%s"):format(module, event),
        event = event,
        ---@param args? { destination: string, source: string }|string
        ---@return neotree.event.Handler.Result|nil|? result
        handler = function(args)
          if not args then
            return
          end
          local mod_args = type(args) == "table"
              and { new_name = args.destination, old_name = args.source }
            or { fname = args } --[[@as { fname: string }|{ new_name: string, old_name: string }]]
          local ok, mod = pcall(require, module) ---@type boolean, LspFileOps.AllModules|nil|?
          if ok and mod then -- translate neo-tree arguemnts to the same format as nvim-tree
            mod(mod_args)
          end
        end,
      }
      neo_tree_events.unsubscribe(sub_args) -- just in case setup is called twice, unsubscribe from event
      neo_tree_events.subscribe(sub_args)
    end)
    Log.debug("Neo-tree integration setup complete")
  end

  if pcall(require, "triptych") then -- triptych integration
    Log.debug("Setting up triptych integration")

    setup_events({
      didCreateFiles = { "TriptychDidCreateNode" },
      didDeleteFiles = { "TriptychDidDeleteNode" },
      didRenameFiles = { "TriptychDidMoveNode" },
      willCreateFiles = { "TriptychWillCreateNode" },
      willDeleteFiles = { "TriptychWillDeleteNode" },
      willRenameFiles = { "TriptychWillMoveNode" },
    }, function(module, event)
      vim.api.nvim_create_autocmd("User", {
        group = "TriptychEvents",
        pattern = event,
        callback = function(ev)
          local ok, mod = pcall(require, module) ---@type boolean, LspFileOps.AllModules|nil|?
          if ok and mod then
            mod(
              (ev.data.from_path and ev.data.to_path)
                  and { new_name = ev.data.to_path, old_name = ev.data.from_path }
                or { fname = ev.data.path }
            )
          end
        end,
      })
    end)
    Log.debug("triptych integration setup complete")
  end

  if config.auto_save then
    local cb = vim.lsp.util.apply_workspace_edit

    ---@param workspace_edit lsp.WorkspaceEdit
    ---@param position_encoding 'utf-16'|'utf-32'|'utf-8'
    vim.lsp.util.apply_workspace_edit = function(workspace_edit, position_encoding) ---@diagnostic disable-line:duplicate-set-field
      if pcall(cb, workspace_edit, position_encoding) then
        save_buffers(extract_uris(workspace_edit))
      else
        Log.error("Failed to apply workspace edit!")
      end
    end
  end
end

return M
