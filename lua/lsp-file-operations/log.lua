---@enum LspFileOps.LogLevelEnum
local levels = {
  debug = vim.log.levels.DEBUG,
  error = vim.log.levels.ERROR,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
}

---@class LspFileOps.Log
---@field level "debug"|"info"|"error"|"warn"
local M = {}

M.level = "error"

---@param level "debug"|"info"|"error"|"warn"
---@return fun(...: any) cb
local function gen_log_func(level)
  require("lsp-file-operations.utils").validate({ level = { level, { "string" } } })

  return function(...)
    if levels[M.level] <= levels[level] then
      local msg = ""
      for i = 1, select("#", ...) do
        local arg = select(i, ...)
        msg = ("%s %s"):format(
          msg,
          arg == nil and ""
            or (
              type(arg) == "string" and arg
              or (
                (type(arg) == "number" or type(arg) == "boolean") and tostring(arg)
                or vim.inspect(arg)
              )
            )
        )
      end

      if msg == "" then -- NOTE: Avoid notifying on empty output
        return
      end

      vim.schedule(function() -- HACK: Use `vim.schedule` to avoid mangling the output of tests
        vim.notify(("nvim-lsp-file-operations [%s]: %s"):format(level:upper(), msg), levels[level])
      end)
    end
  end
end

M.debug = gen_log_func("debug")
M.error = gen_log_func("error")
M.info = gen_log_func("info")
M.warn = gen_log_func("warn")

return M
