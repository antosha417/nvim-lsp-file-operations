local M = {}

local log = require("lsp-file-operations.log")

local default_config = {
  debug = false,
  timeout_ms = 10000,
}

---@alias HandlerMap table<string, string[]> a mapping from modules to events that trigger it

--- helper function to subscribe events to a given module callback
---@param module_events HandlerMap the table that maps modules to event strings
---@param subscribe fun(module: string, event: string) the function for how to subscribe a module to an event
local function setup_events(module_events, subscribe)
  for module, events in pairs(module_events) do
    vim.tbl_map(function(event)
      subscribe(module, event)
    end, events)
  end
end

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  if M.config.debug then
    log.level = "debug"
  end

  -- nvim-tree integration
  local ok_nvim_tree, nvim_tree_api = pcall(require, "nvim-tree.api")
  if ok_nvim_tree then
    log.debug("Setting up nvim-tree integration")

    ---@type HandlerMap
    local nvim_tree_event = nvim_tree_api.events.Event
    local events = {
      ["lsp-file-operations.will-rename"] = { nvim_tree_event.WillRenameNode },
      ["lsp-file-operations.did-rename"] = { nvim_tree_event.NodeRenamed },
      ["lsp-file-operations.will-create"] = { nvim_tree_event.WillCreateFile },
      ["lsp-file-operations.did-create"] = { nvim_tree_event.FileCreated, nvim_tree_event.FolderCreated },
      ["lsp-file-operations.will-delete"] = { nvim_tree_event.WillRemoveFile },
      ["lsp-file-operations.did-delete"] = { nvim_tree_event.FileRemoved, nvim_tree_event.FolderRemoved },
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

    ---@type HandlerMap
    local events = {
      ["lsp-file-operations.will-rename"] = { neo_tree_events.BEFORE_FILE_RENAME, neo_tree_events.BEFORE_FILE_MOVE },
      ["lsp-file-operations.did-rename"] = { neo_tree_events.FILE_RENAMED, neo_tree_events.FILE_MOVED },
      ["lsp-file-operations.did-create"] = { neo_tree_events.FILE_ADDED },
      ["lsp-file-operations.did-delete"] = { neo_tree_events.FILE_DELETED },
      -- currently no events in neo-tree for before creating or deleting, so unable to support those file operations
    }
    setup_events(events, function(module, event)
      -- create an event name based on the module and the event
      local id = ("%s.%s"):format(module, event)
      -- just in case setup is called twice, unsubscribe from event
      neo_tree_events.unsubscribe({ id = id })
      neo_tree_events.subscribe({
        id = id,
        event = event,
        handler = function(args)
          -- translate neo-tree arguemnts to the same format as nvim-tree
          if type(args) == "table" then
            args = { old_name = args.source, new_name = args.destination }
          else
            args = { fname = args }
          end
          -- load module and call the callback
          require(module).callback(args)
        end,
      })
    end)
    log.debug("Neo-tree integration setup complete")
  end
end

return M
