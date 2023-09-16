local utils = require("lsp-file-operations.utils")
local log = require("lsp-file-operations.log")
local scandir = require("plenary.scandir")

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

M.callback = function(opts, data)
  for _, client in pairs(vim.lsp.get_active_clients()) do
    local will_rename = utils.get_nested_path(client,
      { "server_capabilities", "workspace", "fileOperations", "willRename" })
    if will_rename ~= nil then
      local filters = will_rename.filters or {}
      local do_recursive_rename = false
      local files = {}

      if opts.recursive_rename then
        -- We have recursive rename enabled, lets check if the file is a directory
        local _, is_dir = utils.get_absolute_path(data.old_name)
        -- We perform the recursive rename only if is a directory
        do_recursive_rename = is_dir
      end

      if do_recursive_rename then
        -- We have to perfrom the recursive rename, lets scan the received directory  
        for _, value in ipairs(scandir.scan_dir(data.old_name)) do
          table.insert(files, { old_name = value, new_name = value:gsub(data.old_name, data.new_name) })
         end
      else
        -- Not performing the recursive scan, lets just process the single file  
        table.insert(files, { old_name = data.old_name, new_name = data.new_name })
      end

      -- Iterate over the files and apply the workspace edit
      for _, file in ipairs(files) do
        if utils.matches_filters(filters, file.old_name) then
          local edit = getWorkspaceEdit(client, file.old_name, file.new_name)
          if edit ~= nil then
            log.debug("going to apply workspace edit", edit)
            vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
          end
        end
      end
    end
  end
end

return M
