---@module "lsp-file-operations._meta"

local utils = require("lsp-file-operations.utils")

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

local config = nil ---@type LspFileOpsConfig|nil|?

--- helper function to subscribe events to a given module callback
---@param op_events LspFileOpsEvents the table that maps modules to event strings
---@param subscribe fun(module: string, event: string) the function for how to subscribe a module to an event
local function setup_events(op_events, subscribe)
  utils.validate({
    op_events = { op_events, { "table" } },
    subscribe = { subscribe, { "function" } },
  })

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
  require("lsp-file-operations.log").debug("Config modified to", config)
end

---@param opts? LspFileOpsConfig
function M.setup(opts)
  utils.validate({ opts = { opts, { "table", "nil" }, true } })
  opts = opts or {}

  utils.validate({
    ["opts.debug"] = { opts.debug, { "boolean", "nil" }, true },
    ["opts.operations"] = { opts.operations, { "table", "nil" }, true },
    ["opts.timeout_ms"] = { opts.timeout_ms, { "number", "nil" }, true },
  })

  config = vim.tbl_deep_extend("force", default_config, opts)

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
    log.debug("Setting up neo-tree integration")

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
    log.debug("triptych integration setup complete")
  end
end

return M
