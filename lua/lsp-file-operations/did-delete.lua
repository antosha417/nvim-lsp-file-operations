---@class LspFileOps.DidDelete
local M = {}

---@param data { fname: string }
function M.callback(data)
  local utils = require("lsp-file-operations.utils")
  utils.validate({
    data = { data, { "table" } },
    ["data.fname"] = { data.fname, { "string" } },
  })

  for _, client in ipairs(utils.get_clients()) do
    if client.initialized then
      local did_delete = utils.get_nested_path(
        client,
        { "server_capabilities", "workspace", "fileOperations", "didDelete" }
      )
      if did_delete and utils.matches_filters(did_delete.filters or {}, data.fname) then
        local params = { files = { { uri = vim.uri_from_fname(data.fname) } } }
        utils.client_notify(client, "workspace/didDeleteFiles", params)
        require("lsp-file-operations.log").debug(
          "Sending workspace/didDeleteFiles notification",
          params
        )
      end
    end
  end
end

return M
