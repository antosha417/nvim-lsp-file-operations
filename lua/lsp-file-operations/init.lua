---@module "lsp-file-operations._meta"

local default_config = { ---@type LspFileOpsConfig
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

local config = vim.deepcopy(default_config)

---@class LspFileOps
local M = {}

---@return LspFileOpsConfig config
function M.get_config()
  return config
end

---@param cfg? LspFileOpsConfig
function M.set_config(cfg)
  if cfg and type(cfg) == "table" then
    for k, v in pairs(cfg) do
      config[k] = v
    end
  else
    config = cfg
  end
end

--- helper function to subscribe events to a given module callback
---@param op_events table<string, string[]> the table that maps modules to event strings
---@param subscribe fun(module: string, event: string) the function for how to subscribe a module to an event
local function setup_events(op_events, subscribe)
  require("lsp-file-operations.utils").validate({
    op_events = { op_events, { "table" } },
    subscribe = { subscribe, { "function" } },
  })

  ---@enum LspFileOpsModules
  local modules = {
    didCreateFiles = "lsp-file-operations.did-create",
    didDeleteFiles = "lsp-file-operations.did-delete",
    didRenameFiles = "lsp-file-operations.did-rename",
    willCreateFiles = "lsp-file-operations.will-create",
    willDeleteFiles = "lsp-file-operations.will-delete",
    willRenameFiles = "lsp-file-operations.will-rename",
  }
  for operation, enabled in pairs(config.operations) do
    ---@cast operation string
    ---@cast enabled boolean
    if enabled and modules[operation] and op_events[operation] then
      vim.tbl_map(function(event) ---@param event string
        subscribe(modules[operation], event)
        return event -- NOTE: This is just to avoid an LSP warning, not used at all
      end, op_events[operation])
    end
  end
end

---@param opts? LspFileOpsConfig
function M.setup(opts)
  require("lsp-file-operations.utils").validate({ opts = { opts, { "table", "nil" }, true } })

  config = vim.tbl_deep_extend("force", default_config, opts or {})

  local log = require("lsp-file-operations.log")
  if config.debug then
    log.level = "debug"
  end

  local ok_nvim_tree, nvim_tree_api = pcall(require, "nvim-tree.api")
  if ok_nvim_tree and nvim_tree_api then -- nvim-tree integration
    log.debug("Setting up nvim-tree integration")

    setup_events({
      didCreateFiles = {
        nvim_tree_api.events.Event.FileCreated,
        nvim_tree_api.events.Event.FolderCreated,
      },
      didDeleteFiles = {
        nvim_tree_api.events.Event.FileRemoved,
        nvim_tree_api.events.Event.FolderRemoved,
      },
      didRenameFiles = { nvim_tree_api.events.Event.NodeRenamed },
      willCreateFiles = { nvim_tree_api.events.Event.WillCreateFile },
      willDeleteFiles = { nvim_tree_api.events.Event.WillRemoveFile },
      willRenameFiles = { nvim_tree_api.events.Event.WillRenameNode },
    }, function(module, event)
      nvim_tree_api.events.subscribe(event, function(args)
        require(module).callback(args)
      end)
    end)
  end

  local ok_neo_tree, neo_tree_events = pcall(require, "neo-tree.events")
  if ok_neo_tree and neo_tree_events then -- neo-tree integration
    log.debug("Setting up neo-tree integration")

    setup_events({
      didCreateFiles = { neo_tree_events.FILE_ADDED },
      didDeleteFiles = { neo_tree_events.FILE_DELETED },
      didRenameFiles = { neo_tree_events.FILE_RENAMED, neo_tree_events.FILE_MOVED },
      willCreateFiles = { neo_tree_events.BEFORE_FILE_ADD },
      willDeleteFiles = { neo_tree_events.BEFORE_FILE_DELETE },
      willRenameFiles = { neo_tree_events.BEFORE_FILE_RENAME, neo_tree_events.BEFORE_FILE_MOVE },
    }, function(module, event)
      local sub_args = {
        id = ("%s.%s"):format(module, event),
        event = event,
        handler = function(args) ---@param args { source: string, destination: string }|string
          -- translate neo-tree arguemnts to the same format as nvim-tree
          require(module).callback(
            type(args) == "table" and { new_name = args.destination, old_name = args.source }
              or { fname = args }
          )
        end,
      }
      neo_tree_events.unsubscribe(sub_args) -- just in case setup is called twice, unsubscribe from event
      neo_tree_events.subscribe(sub_args)
    end)
    log.debug("Neo-tree integration setup complete")
  end

  if pcall(require, "triptych") then -- triptych integration
    log.debug("Setting up triptych integration")

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
          require(module).callback(
            (ev.data.from_path and ev.data.to_path)
                and { new_name = ev.data.to_path, old_name = ev.data.from_path }
              or { fname = ev.data.path }
          )
        end,
      })
    end)
    log.debug("triptych integration setup complete")
  end
end

---The extra client capabilities provided by this plugin. To be merged with
---`vim.lsp.protocol.make_client_capabilities()` and sent to the LSP server.
---@return lsp.ClientCapabilities capabilities
function M.default_capabilities()
  local result = { workspace = { fileOperations = {} } } ---@type lsp.ClientCapabilities
  config = config or default_config
  for operation, capability in pairs({
    didCreateFiles = "didCreate",
    didDeleteFiles = "didDelete",
    didRenameFiles = "didRename",
    willCreateFiles = "willCreate",
    willDeleteFiles = "willDelete",
    willRenameFiles = "willRename",
  }) do
    result.workspace.fileOperations[capability] = config.operations[operation]
  end
  return result
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
