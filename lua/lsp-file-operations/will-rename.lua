---@alias LspFileOps.WillRename fun(data: { new_name: string, old_name: string })

---@param data { new_name: string, old_name: string }
return function(data)
  local utils = require("lsp-file-operations.utils")
  utils.validate({
    data = { data, { "table" } },
    ["data.new_name"] = { data.new_name, { "string" } },
    ["data.old_name"] = { data.old_name, { "string" } },
  })

  for _, client in ipairs(utils.get_clients()) do
    if client.initialized then
      local will_rename = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "willRename" }
      )
      if will_rename and utils.matches_filters(will_rename.filters or {}, data.old_name) then
        local edit =
          utils.get_workspace_edit("willRenameFiles", client, data.old_name, data.new_name)
        if edit then
          require("lsp-file-operations.log").debug("Applying workspace/willRenameFiles edit", edit)
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end
    end
  end
end
