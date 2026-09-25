---@alias LspFileOps.WillCreate fun(data: { fname: string })

---@param data { fname: string }
return function(data)
  local utils = require("lsp-file-operations.utils")
  utils.validate({
    data = { data, { "table" } },
    ["data.fname"] = { data.fname, { "string" } },
  })

  for _, client in ipairs(utils.get_clients()) do
    if client.initialized then
      local will_create = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "willCreate" }
      )
      if will_create and utils.matches_filters(will_create.filters or {}, data.fname) then
        local edit = utils.get_workspace_edit("willCreateFiles", client, data.fname)
        if edit then
          require("lsp-file-operations.log").debug("Applying workspace/willCreateFiles edit", edit)
          vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
        end
      end
    end
  end
end
