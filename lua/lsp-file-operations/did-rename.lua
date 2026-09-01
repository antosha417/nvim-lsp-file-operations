local uri = vim.uri_from_fname

local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")

---@class LspFileOps.DidRename
local M = {}

function M.callback(data)
  utils.validate({ data = { data, { "table" } } })

  local clients = utils.get_clients()
  for _, client in pairs(clients) do
    if client.initialized ~= nil and client.initialized then
      local did_rename = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "didRename" }
      )
      if did_rename and utils.matches_filters(did_rename.filters or {}, data.old_name) then
        local params = { files = { { oldUri = uri(data.old_name), newUri = uri(data.new_name) } } }
        utils.client_notify(client, "workspace/didRenameFiles", params)
        log.debug("Sending workspace/didRenameFiles notification", params)
      end
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
