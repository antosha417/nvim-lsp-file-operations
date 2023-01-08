local M = {}

local will_rename = require('lsp-file-operations.will-rename')
local log = require('lsp-file-operations.log')

local default_config = {
  debug = false
}

M.setup = function(opts)
  opts = vim.tbl_deep_extend("force", default_config, opts)
  if opts.debug then
    log.level = "debug"
  end
  local ok, tree_api = pcall(require, 'nvim-tree.api')
  if ok then
    log.debug("Setting up nvim-tree integration")
    tree_api.events.subscribe(tree_api.events.Event.WillRenameNode, will_rename.callback)
  end
end

return M
