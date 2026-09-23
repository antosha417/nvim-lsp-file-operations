---@alias LspFileOps.DidCreate fun(data: { fname: string })

---@param data { fname: string }
return function(data)
  local utils = require("lsp-file-operations.utils")
  utils.validate({
    data = { data, { "table" } },
    ["data.fname"] = { data.fname, { "string" } },
  })

  for _, client in ipairs(utils.get_clients()) do
    if client.initialized then
      local did_create = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "didCreate" }
      )
      if did_create and utils.matches_filters(did_create.filters or {}, data.fname) then
        local params = { files = { { uri = vim.uri_from_fname(data.fname) } } }
        utils.client_notify(client, "workspace/didCreateFiles", params)
        require("lsp-file-operations.log").debug(
          "Sending workspace/didCreateFiles notification",
          params
        )
      end
    end
  end
end
