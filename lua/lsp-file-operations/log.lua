---@enum LspFileOps.LogLevelEnum
local levels = {
  debug = vim.log.levels.DEBUG,
  error = vim.log.levels.ERROR,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
}

local output = vim.fs.joinpath(vim.fn.stdpath("cache"), "lsp-file-operations.log")

---@param mode string
---@return integer fmode
local function fmode(mode)
  return tonumber(mode, 8)
end

---@param msg string
local function write_output(msg)
  require("lsp-file-operations.utils").validate({ msg = { msg, { "string" } } })

  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(output)
  if stat and stat.type == "directory" then
    return
  end

  local fd ---@type integer|nil|?
  if not stat then
    fd = uv.fs_open(output, "w", fmode("644"))
    if not fd then
      return
    end
    uv.fs_close(fd)
  end

  fd = uv.fs_open(output, "r", fmode("644"))
  if not fd then
    return
  end

  stat = uv.fs_stat(output)
  if not stat then
    uv.fs_close(fd)
    return
  end

  local data = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  if not data then
    return
  end

  fd = uv.fs_open(output, "w", fmode("664"))
  if fd then
    uv.fs_write(fd, ("%s%s%s"):format(data, data ~= "" and "\n" or "", msg))
    uv.fs_close(fd)
  end
end

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

      if msg ~= "" then -- NOTE: Avoid notifying on empty output
        vim.schedule(function() -- HACK: Use `vim.schedule` to avoid mangling the output of tests
          local date = os.date("*t") --[[@as osdate]]
          local txt = ("[nvim-lsp-file-operations] [%s %d-%d-%d %02d:%02d:%02d]: %s"):format(
            level:upper(),
            date.year,
            date.month,
            date.day,
            date.hour,
            date.min,
            date.sec,
            msg
          )
          vim.notify(txt, levels[level])
          write_output(txt)
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
