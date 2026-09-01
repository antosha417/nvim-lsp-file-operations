local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")

---@class LspFileOps.WillCreate
local M = {}

---@param client vim.lsp.Client
---@param fname string
---@return lsp.WorkspaceEdit|nil
local function getWorkspaceEdit(client, fname)
  utils.validate({
    client = { client, { "table" } },
    fname = { fname, { "string" } },
  })

  local will_create_params = { files = { { uri = vim.uri_from_fname(fname) } } }
  log.debug("Sending workspace/willCreateFiles request", will_create_params)
  local timeout_ms = require("lsp-file-operations").config.timeout_ms
  local success, resp =
    pcall(client.request_sync, "workspace/willCreateFiles", will_create_params, timeout_ms)
  log.debug("Got workspace/willCreateFiles response", resp)
  if not success then
    log.error("Error while sending workspace/willCreateFiles request", resp)
    return
  end
  if not (resp and resp.result) then
    log.warn("Got empty workspace/willCreateFiles response, maybe a timeout?")
    return
  end
  return resp.result
end

function M.callback(data)
  utils.validate({ data = { data, { "table" } } })

  local clients = utils.get_clients()
  for _, client in pairs(clients) do
    if client.initialized ~= nil and client.initialized then
      local will_create = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "willCreate" }
      )
      if will_create and utils.matches_filters(will_create.filters or {}, data.fname) then
        local edit = getWorkspaceEdit(client, data.fname)
        if edit then
          log.debug("Going to apply workspace/willCreateFiles edit", edit)
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
