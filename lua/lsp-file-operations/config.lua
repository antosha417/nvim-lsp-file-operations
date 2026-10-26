---@module "lsp-file-operations._meta"

local Util = require("lsp-file-operations.util")

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

local default_config = { ---@type LFOConfig
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

local config = nil ---@type LFOConfig|nil|?

---Safely writes a specific buffer to disk if it has unsaved mutations
---
---Sourced from `nvim-file-operations`, all credits go to @Crysthamus.
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations/autosave.lua
---@type fun(uris: string[])
local save_buffers = vim.schedule_wrap(function(uris) ---@param uris string[]
  Util.validate({ uris = { uris, { "table" } } })

  local Log = require("lsp-file-operations.log")
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

---Parse an incoming `lsp.WorkspaceEdit` structure and extracts modified files.
---
---Sourced from `nvim-file-operations`, all credits go to @Crysthamus.
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations/autosave.lua
---
---@param workspace_edit lsp.WorkspaceEdit The standard LSP WorkspaceEdit object payload
---@return string[] uris Array of unique URIs
local function extract_uris(workspace_edit)
  Util.validate({ workspace_edit = { workspace_edit, { "table" } } })

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
  return Util.dedup(uris)
end

---Helper function to subscribe events to a given module callback
---@param op_events LFOEvents the table that maps modules to event strings
---@param subscribe fun(module: string, event: string) the function for how to subscribe a module to an event
local function setup_events(op_events, subscribe)
  Util.validate({
    op_events = { op_events, { "table" } },
    subscribe = { subscribe, { "function" } },
  })

  if not config then
    return
  end

  local modules = { ---@type table<LFOConfig.Operations, string>
    didCreateFiles = "did_create",
    didDeleteFiles = "did_delete",
    didRenameFiles = "did_rename",
    willCreateFiles = "will_create",
    willDeleteFiles = "will_delete",
    willRenameFiles = "will_rename",
  }
  for operation, enabled in pairs(config.operations) do
    ---@cast operation LFO.Operations
    ---@cast enabled boolean
    if enabled and modules[operation] and op_events[operation] then
      vim.tbl_map(function(event) ---@param event string
        subscribe(modules[operation], event)
        return event -- NOTE: This is just to avoid an LSP warning, not used at all
      end, op_events[operation])
    end
  end
end

---@class LFO.Config
---@field get fun(): config: LFOConfig
---@field get_defaults fun(): default_config: LFOConfig
---@field set (fun())|(fun(cfg: LFOConfig))
local M = {}

setmetatable(M, {
  __index = function(self, k) ---@param self LFO.Config
    local raw = Util.get(self, k)
    if raw ~= nil then
      return raw
    end

    if type(k) ~= "string" then
      return
    end

    ---@cast k string
    if k == "get" then
      return get(self, k, function()
        return config
      end)
    end

    if k == "get_defaults" then
      return get(self, k, function()
        return default_config
      end)
    end

    if k == "set" then
      return get(self, k, function(cfg)
        config = cfg
        require("lsp-file-operations.log").debug("Config modified to", config)
      end)
    end
  end,
})

---@param opts LFOConfig
---@overload fun()
function M.setup(opts)
  Util.validate({ opts = { opts, { "table", "nil" }, true } })
  opts = opts or {}

  Util.validate({
    ["opts.auto_save"] = { opts.auto_save, { "boolean", "nil" }, true },
    ["opts.debug"] = { opts.debug, { "boolean", "nil" }, true },
    ["opts.operations"] = { opts.operations, { "table", "nil" }, true },
    ["opts.timeout_ms"] = { opts.timeout_ms, { "number", "nil" }, true },
  })

  config = vim.tbl_deep_extend("force", default_config, opts)

  for k, v in pairs(config.operations) do
    if type(v) ~= "boolean" then
      config.operations[k] = default_config.operations[k]
    end
  end

  local Log = require("lsp-file-operations.log")
  Log.setup()

  if config.debug then
    Log.set_level("debug")
  end

  local group = vim.api.nvim_create_augroup("LSPFileOps.Integrations", { clear = true })
  if package.loaded["nvim-tree"] ~= nil then -- nvim-tree integration
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "NvimTree",
      callback = function()
        Log.debug("Setting up nvim-tree integration")

        local nvim_tree_api = require("nvim-tree.api")
        local ev = nvim_tree_api.events.Event
        setup_events({
          didCreateFiles = { ev.FileCreated, ev.FolderCreated },
          didDeleteFiles = { ev.FileRemoved, ev.FolderRemoved },
          didRenameFiles = { ev.NodeRenamed },
          willCreateFiles = { ev.WillCreateFile },
          willDeleteFiles = { ev.WillRemoveFile },
          willRenameFiles = { ev.WillRenameNode },
        }, function(module, event)
          nvim_tree_api.events.subscribe(event, require("lsp-file-operations")[module])
        end)
        Log.debug("nvim-tree integration setup complete")
      end,
    })
  end

  if package.loaded["neo-tree"] ~= nil then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "neo-tree",
      callback = function()
        local neo_tree_events = require("neo-tree.events")
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
            handler = function(args) ---@param args? { destination: string, source: string }|string
              if args then
                require("lsp-file-operations")[module](
                  type(args) == "table" and { new_name = args.destination, old_name = args.source }
                    or { fname = args }
                )
              end
            end,
          }
          neo_tree_events.unsubscribe(sub_args) -- just in case setup is called twice, unsubscribe from event
          neo_tree_events.subscribe(sub_args)
        end)
        Log.debug("Neo-tree integration setup complete")
      end,
    })
  end

  if package.loaded["triptych"] ~= nil then -- triptych integration
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "triptych",
      callback = function()
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
              require("lsp-file-operations")[module](
                (ev.data.from_path and ev.data.to_path)
                    and { new_name = ev.data.to_path, old_name = ev.data.from_path }
                  or { fname = ev.data.path }
              )
            end,
          })
        end)
        Log.debug("triptych integration setup complete")
      end,
    })
  end

  if config.auto_save then
    local cb = vim.lsp.util.apply_workspace_edit

    --- Applies a `WorkspaceEdit`.
    ---
    ---@param workspace_edit lsp.WorkspaceEdit
    ---@param position_encoding 'utf-8'|'utf-16'|'utf-32' (required)
    ---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
    ---@diagnostic disable-next-line:duplicate-set-field
    vim.lsp.util.apply_workspace_edit = function(workspace_edit, position_encoding)
      if pcall(cb, workspace_edit, position_encoding) then
        save_buffers(extract_uris(workspace_edit))
      else
        Log.error("Failed to apply workspace edit!")
      end
    end
  end
end

return M
