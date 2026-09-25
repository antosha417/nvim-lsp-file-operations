---@alias LspFileOps.DidRename fun(data: { old_name: string, new_name: string })

---@param data { old_name: string, new_name: string }
return function(data)
  local utils = require("lsp-file-operations.utils")
  utils.validate({
    data = { data, { "table" } },
    ["data.new_name"] = { data.new_name, { "string" } },
    ["data.old_name"] = { data.old_name, { "string" } },
  })

  for _, client in ipairs(utils.get_clients()) do
    if client.initialized then
      local did_rename = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "didRename" }
      )
      if did_rename and utils.matches_filters(did_rename.filters or {}, data.old_name) then
        local params = {
          files = {
            {
              newUri = vim.uri_from_fname(data.new_name),
              oldUri = vim.uri_from_fname(data.old_name),
            },
          },
        }
        utils.client_notify(client, "workspace/didRenameFiles", params)
        require("lsp-file-operations.log").debug(
          "Sending workspace/didRenameFiles notification",
          params
        )
      end
    end
  end
end
