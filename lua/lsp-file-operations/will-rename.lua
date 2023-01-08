local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")

local M = {}

local function getWorkspaceEdit(client, old_name, new_name)
  log.debug("going to get workspace edit")
  local will_rename_params = {
    files = {
      {
        oldUri = "file://" .. old_name,
        newUri = "file://" .. new_name,
      }
    }
  }
  log.debug("Sending workspace/willRenameFiles request", will_rename_params)
  -- TODO get timeout from config
  local resp = client.request_sync("workspace/willRenameFiles", will_rename_params, 1000)
  log.debug("Got workspace/willRenameFiles response", resp)
  return resp.result
end

M.callback = function(data)
  for _, client in pairs(vim.lsp.get_active_clients()) do
    local will_rename = utils.get_nested_path(client,
      { "server_capabilities", "workspace", "fileOperations", "willRename" })
    if will_rename ~= nil then
      local filters = will_rename.filters or {}
      if utils.matches_filters(filters, data.old_name) then
        local edit = getWorkspaceEdit(client, data.old_name, data.new_name)
        if edit ~= nil then
          log.debug("going to apply workspace edit", edit)
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end
    end
  end
end

return M
