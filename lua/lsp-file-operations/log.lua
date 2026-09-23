local utils = require("lsp-file-operations.utils")

---@class LspFileOps.Log
---@field level "debug"|"info"|"error"|"warn"
local M = {}

M.level = "error"

---@param level "debug"|"info"|"error"|"warn"
---@return fun(...: any) cb
local function gen_log_func(level)
  utils.validate({ level = { level, { "string" } } })

  ---@enum LspFileOps.LogLevelEnum
  local levels = {
    debug = vim.log.levels.DEBUG,
    error = vim.log.levels.ERROR,
    info = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
  }
  return function(...)
    if levels[M.level] <= levels[level] then
      local msg = ""
      for i = 1, select("#", ...) do
        local new, arg = "", select(i, ...)
        if arg == nil then
          new = ""
        elseif type(arg) == "string" then
          new = arg --[[@as string]]
        elseif type(arg) == "number" or type(arg) == "boolean" then
          new = tostring(arg)
        else
          new = vim.inspect(arg)
        end
        msg = ("%s %s"):format(msg, new)
      end

      if msg ~= "" then
        vim.schedule(function()
          vim.notify(
            ("nvim-lsp-file-operations [%s]: %s"):format(level:upper(), msg),
            levels[level]
          )
        end)
      end
    end
  end
end

M.debug = gen_log_func("debug")
M.error = gen_log_func("error")
M.info = gen_log_func("info")
M.warn = gen_log_func("warn")

return M

-- vim: set ts=2 sts=2 sw=2 et ai si sta:
