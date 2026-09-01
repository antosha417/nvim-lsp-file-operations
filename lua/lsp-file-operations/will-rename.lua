local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")

---@class LspFileOps.WillRename
local M = {}

---@param client vim.lsp.Client
---@param old_name string
---@param new_name string
---@return lsp.WorkspaceEdit|nil
local function getWorkspaceEdit(client, old_name, new_name)
  utils.validate({
    client = { client, { "table" } },
    old_name = { old_name, { "string" } },
    new_name = { new_name, { "string" } },
  })

  local will_rename_params = {
    files = { { oldUri = vim.uri_from_fname(old_name), newUri = vim.uri_from_fname(new_name) } },
  }
  log.debug("Sending workspace/willRenameFiles request", will_rename_params)
  local timeout_ms = require("lsp-file-operations").config.timeout_ms
  local success, resp =
    pcall(client.request_sync, "workspace/willRenameFiles", will_rename_params, timeout_ms)
  log.debug("Got workspace/willRenameFiles response", resp)
  if not success then
    log.error("Error while sending workspace/willRenameFiles request", resp)
    return
  end
  if not (resp and resp.result) then
    log.warn("Got empty workspace/willRenameFiles response, maybe a timeout?")
    return
  end
  return resp.result
end

function M.callback(data)
  utils.validate({ data = { data, { "table" } } })

  local clients = utils.get_clients()
  for _, client in pairs(clients) do
    if client.initialized ~= nil and client.initialized then
      local will_rename = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "willRename" }
      )
      if will_rename and utils.matches_filters(will_rename.filters or {}, data.old_name) then
        local edit = getWorkspaceEdit(client, data.old_name, data.new_name)
        if edit then
          log.debug("Going to apply workspace/willRename edit", edit)
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
