local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")

---@class LspFileOps.DidCreate
local M = {}

function M.callback(data)
  utils.validate({ data = { data, { "table" } } })

  local clients = utils.get_clients()
  for _, client in pairs(clients) do
    if client.initialized ~= nil and client.initialized then
      local did_create = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "didCreate" }
      )
      if did_create and utils.matches_filters(did_create.filters or {}, data.fname) then
        local params = { files = { { uri = vim.uri_from_fname(data.fname) } } }
        utils.client_notify(client, "workspace/didCreateFiles", params)
        log.debug("Sending workspace/didCreateFiles notification", params)
      end
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
