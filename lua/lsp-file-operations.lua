local M = {}

local log = require("lsp-file-operations.log")

local default_config = {
  debug = false,
  timeout_ms = 10000,
}

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  if M.config.debug then
    log.level = "debug"
  end

  -- nvim-tree integration
  local ok_nvim_tree, nvim_tree_api = pcall(require, "nvim-tree.api")
  if ok_nvim_tree then
    log.debug("Setting up nvim-tree integration")
    nvim_tree_api.events.subscribe(nvim_tree_api.events.Event.WillRenameNode, function(data)
      require("lsp-file-operations.will-rename").callback(data)
    end)
    nvim_tree_api.events.subscribe(nvim_tree_api.events.Event.NodeRenamed, function(data)
      require("lsp-file-operations.did-rename").callback(data)
    end)
  end

  -- neo-tree integration
  local ok_neo_tree, neo_tree_events = pcall(require, "neo-tree.events")
  if ok_neo_tree then
    log.debug("Setting up neo-tree integration")

    -- We need to convert the neo-tree event data to the same format as nvim-tree
    local callback = function(args)
      local data = {
        old_name = args.source,
        new_name = args.destination,
      }
      log.debug("LSP will rename data", vim.inspect(data))
      require("lsp-file-operations.will-rename").callback(data)
    end

    local did_rename_callback = function(args)
      local data = {
        old_name = args.source,
        new_name = args.destination,
      }
      log.debug("LSP did rename data", vim.inspect(data))
      require("lsp-file-operations.did-rename").callback(data)
    end

    -- just in case setup is called multiple times
    local will_rename_id = "nvim_lsp_file_operations_will_rename"
    local will_move_id = "nvim_lsp_file_operations_will_move"
    local did_rename_id = "nvim_lsp_file_operations_did_rename"
    local did_move_id = "nvim_lsp_file_operations_did_move"
    neo_tree_events.unsubscribe({ id = will_rename_id })
    neo_tree_events.unsubscribe({ id = will_move_id })
    neo_tree_events.unsubscribe({ id = did_rename_id })
    neo_tree_events.unsubscribe({ id = did_move_id })

    -- now subscribe to the events
    neo_tree_events.subscribe({
      id = will_rename_id,
      event = neo_tree_events.BEFORE_FILE_RENAME,
      handler = callback,
    })
    neo_tree_events.subscribe({
      id = will_move_id,
      event = neo_tree_events.BEFORE_FILE_MOVE,
      handler = callback,
    })
    neo_tree_events.subscribe({
      id = did_rename_id,
      event = neo_tree_events.FILE_RENAMED,
      handler = did_rename_callback,
    })
    neo_tree_events.subscribe({
      id = did_move_id,
      event = neo_tree_events.FILE_MOVED,
      handler = did_rename_callback,
    })
    log.debug("Neo-tree integration setup complete")
  end
end

return M
