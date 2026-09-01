local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")

---@class LspFileOps.WillDelete
local M = {}

---@param client vim.lsp.Client
---@param fname string
---@return lsp.WorkspaceEdit|nil
local function getWorkspaceEdit(client, fname)
  local will_delete_params = { files = { { uri = vim.uri_from_fname(fname) } } }
  log.debug("Sending workspace/willDeleteFiles request", will_delete_params)
  local timeout_ms = require("lsp-file-operations").config.timeout_ms
  local success, resp =
    pcall(client.request_sync, "workspace/willDeleteFiles", will_delete_params, timeout_ms)
  log.debug("Got workspace/willDeleteFiles response", resp)
  if not success then
    log.error("Error while sending workspace/willDeleteFiles request", resp)
    return
  end
  if not (resp and resp.result) then
    log.warn("Got empty workspace/willDeleteFiles response, maybe a timeout?")
    return
  end
  return resp.result
end

function M.callback(data)
  utils.validate({ data = { data, { "table" } } })

  local clients = utils.get_clients()
  for _, client in pairs(clients) do
    if client.initialized ~= nil and client.initialized then
      local will_delete = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "willDelete" }
      )
      if will_delete and utils.matches_filters(will_delete.filters or {}, data.fname) then
        local edit = getWorkspaceEdit(client, data.fname)
        if edit then
          log.debug("Going to apply workspace/willDelete edit", edit)
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
