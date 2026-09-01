local log = require("lsp-file-operations.log")
local utils = require("lsp-file-operations.utils")

---@class LspFileOpsConfig.Operations
---@field didCreateFiles? boolean
---@field didDeleteFiles? boolean
---@field didRenameFiles? boolean
---@field willCreateFiles? boolean
---@field willDeleteFiles? boolean
---@field willRenameFiles? boolean

---@class LspFileOpsConfig
---@field debug? boolean
---@field timeout_ms? integer
---@field operations? LspFileOpsConfig.Operations
local default_config = {
  debug = false,
  timeout_ms = 10000,
  operations = {
    didCreateFiles = true,
    didDeleteFiles = true,
    didRenameFiles = true,
    willCreateFiles = true,
    willDeleteFiles = true,
    willRenameFiles = true,
  },
}

---@enum LspFileOpsModules
local modules = {
  didCreateFiles = "lsp-file-operations.did-create",
  didDeleteFiles = "lsp-file-operations.did-delete",
  didRenameFiles = "lsp-file-operations.did-rename",
  willCreateFiles = "lsp-file-operations.will-create",
  willDeleteFiles = "lsp-file-operations.will-delete",
  willRenameFiles = "lsp-file-operations.will-rename",
}

---@enum LspFileOpsCapabilities
local capabilities = {
  didCreateFiles = "didCreate",
  didDeleteFiles = "didDelete",
  didRenameFiles = "didRename",
  willCreateFiles = "willCreate",
  willDeleteFiles = "willDelete",
  willRenameFiles = "willRename",
}

---@class LspFileOps
local M = {}

--- helper function to subscribe events to a given module callback
---@param op_events table<string, string[]> the table that maps modules to event strings
---@param subscribe fun(module: string, event: string) the function for how to subscribe a module to an event
local function setup_events(op_events, subscribe)
  utils.validate({
    op_events = { op_events, { "table" } },
    subscribe = { subscribe, { "function" } },
  })

  for operation, enabled in pairs(M.config.operations) do
    if enabled and modules[operation] and op_events[operation] then
      vim.tbl_map(function(event)
        subscribe(modules[operation], event)
      end, op_events[operation])
    end
  end
end

---@param opts? LspFileOpsConfig
function M.setup(opts)
  utils.validate({ opts = { opts, { "table", "nil" }, true } })

  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  if M.config.debug then
    log.level = "debug"
  end

  -- nvim-tree integration
  local ok_nvim_tree, nvim_tree_api = pcall(require, "nvim-tree.api")
  if ok_nvim_tree then
    log.debug("Setting up nvim-tree integration")

    local nvim_tree_event = nvim_tree_api.events.Event
    local events = { ---@type table<string, string[]>
      willRenameFiles = { nvim_tree_event.WillRenameNode },
      didRenameFiles = { nvim_tree_event.NodeRenamed },
      willCreateFiles = { nvim_tree_event.WillCreateFile },
      didCreateFiles = { nvim_tree_event.FileCreated, nvim_tree_event.FolderCreated },
      willDeleteFiles = { nvim_tree_event.WillRemoveFile },
      didDeleteFiles = { nvim_tree_event.FileRemoved, nvim_tree_event.FolderRemoved },
    }
    setup_events(events, function(module, event)
      nvim_tree_api.events.subscribe(event, function(args)
        require(module).callback(args)
      end)
    end)
  end

  -- neo-tree integration
  local ok_neo_tree, neo_tree_events = pcall(require, "neo-tree.events")
  if ok_neo_tree then
    log.debug("Setting up neo-tree integration")

    local events = { ---@type table<string, string[]>
      willRenameFiles = { neo_tree_events.BEFORE_FILE_RENAME, neo_tree_events.BEFORE_FILE_MOVE },
      didRenameFiles = { neo_tree_events.FILE_RENAMED, neo_tree_events.FILE_MOVED },
      didCreateFiles = { neo_tree_events.FILE_ADDED },
      didDeleteFiles = { neo_tree_events.FILE_DELETED },
      -- currently no events in neo-tree for before creating or deleting, so unable to support those file operations
      -- Issue to add the missing events: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/1276
    }
    setup_events(events, function(module, event)
      -- create an event name based on the module and the event
      local id = ("%s.%s"):format(module, event)
      -- just in case setup is called twice, unsubscribe from event
      neo_tree_events.unsubscribe({
        id = id,
        event = event,
        handler = function(args)
          -- load module and call the callback
          require(module).callback(
            -- translate neo-tree arguemnts to the same format as nvim-tree
            type(args) == "table" and { old_name = args.source, new_name = args.destination }
              or { fname = args }
          )
        end,
      })
      neo_tree_events.subscribe({
        id = id,
        event = event,
        handler = function(args)
          -- load module and call the callback
          require(module).callback(
            -- translate neo-tree arguemnts to the same format as nvim-tree
            type(args) == "table" and { old_name = args.source, new_name = args.destination }
              or { fname = args }
          )
        end,
      })
    end)
    log.debug("Neo-tree integration setup complete")
  end

  -- triptych integration
  if pcall(require, "triptych") then
    log.debug("Setting up triptych integration")

    local events = { ---@type table<string, string[]>
      didCreateFiles = { "TriptychDidCreateNode" },
      didDeleteFiles = { "TriptychDidDeleteNode" },
      didRenameFiles = { "TriptychDidMoveNode" },
      willCreateFiles = { "TriptychWillCreateNode" },
      willDeleteFiles = { "TriptychWillDeleteNode" },
      willRenameFiles = { "TriptychWillMoveNode" },
    }
    setup_events(events, function(module, event)
      vim.api.nvim_create_autocmd("User", {
        group = "TriptychEvents",
        pattern = event,
        callback = function(callback_data)
          local data = callback_data.data
          require(module).callback(
            (data.from_path and data.to_path)
                and { old_name = data.from_path, new_name = data.to_path }
              or { fname = data.path }
          )
        end,
      })
    end)
    log.debug("triptych integration setup complete")
  end
end

--- The extra client capabilities provided by this plugin. To be merged with
--- vim.lsp.protocol.make_client_capabilities() and sent to the LSP server.
---@return lsp.ClientCapabilities capabilities
function M.default_capabilities()
  local config = M.config or default_config
  local result = { workspace = { fileOperations = {} } } ---@type lsp.ClientCapabilities
  for operation, capability in pairs(capabilities) do
    result.workspace.fileOperations[capability] = config.operations[operation]
  end
  return result
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
