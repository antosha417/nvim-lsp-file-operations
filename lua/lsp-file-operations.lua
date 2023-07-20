local M = {}

local will_rename = require('lsp-file-operations.will-rename')
local log = require('lsp-file-operations.log')

local default_config = {
  debug = false
}

M.setup = function(opts)
  opts = vim.tbl_deep_extend("force", default_config, opts or {})
  if opts.debug then
    log.level = "debug"
  end

  -- nvim-tree integration
  local ok_nvim_tree, nvim_tree_api = pcall(require, 'nvim-tree.api')
  if ok_nvim_tree then
    log.debug("Setting up nvim-tree integration")
    nvim_tree_api.events.subscribe(nvim_tree_api.events.Event.WillRenameNode, will_rename.callback)
  end

  -- neo-tree integration
  local ok_neo_tree, neo_tree_events = pcall(require, 'neo-tree.events')
  if ok_neo_tree then
    log.debug("Setting up neo-tree integration")

    -- We need to convert the neo-tree event data to the same format as nvim-tree
    local callback = function(args)
      local data = {
        old_name = args.source,
        new_name = args.destination
      }
      log.debug("LSP rename data", vim.inspect(data))
      will_rename.callback(data)
    end

    -- just in case setup is called multiple times
    local rename_id = "nvim_lsp_file_operations_rename"
    local move_id = "nvim_lsp_file_operations_move"
    neo_tree_events.unsubscribe({ id = rename_id })
    neo_tree_events.unsubscribe({ id = move_id })

    -- now subscribe to the events
    neo_tree_events.subscribe({
      id = rename_id,
      event = neo_tree_events.FILE_RENAMED,
      handler = callback
    })
    neo_tree_events.subscribe({
      id = move_id,
      event = neo_tree_events.FILE_MOVED,
      handler = callback
    })
    log.debug("Neo-tree integration setup complete")
  end
end

return M
