---@module "lsp-file-operations._meta"

local Config = require("lsp-file-operations.config")

---@class LspFileOps
local M = {}

M.get_config = Config.get
M.set_config = Config.set

---The extra client capabilities provided by this plugin. To be merged with
---`vim.lsp.protocol.make_client_capabilities()` and sent to the LSP server.
---@return lsp.ClientCapabilities capabilities
function M.default_capabilities()
  local config = Config.get() or Config.get_defaults()
  local result = { workspace = { fileOperations = {} } } ---@type lsp.ClientCapabilities
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

M.setup = Config.setup

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
