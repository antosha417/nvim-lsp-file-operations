local MAX_SIZE = 1048576 -- 1MiB
local OUTPUT = vim.fs.joinpath(vim.fn.stdpath("cache"), "lsp-file-operations.log")
local uv = vim.uv or vim.loop
local Util = require("lsp-file-operations.util")

---@enum LspFileOps.LogLevelEnum
local levels = {
  debug = vim.log.levels.DEBUG,
  error = vim.log.levels.ERROR,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
}

local timer = nil ---@type uv.uv_timer_t|nil|?

---@param msg string
local function write_output(msg)
  Util.validate({ msg = { msg, { "string" } } })

  local stat = uv.fs_stat(OUTPUT)
  if stat and stat.type == "directory" then
    return
  end

  local fd ---@type integer|nil|?
  if not stat then
    fd = uv.fs_open(OUTPUT, "w", Util.fmode("644"))
    if not fd then
      return
    end
    uv.fs_close(fd)
  end

  fd = uv.fs_open(OUTPUT, "r", Util.fmode("644"))
  if not fd then
    return
  end

  stat = uv.fs_stat(OUTPUT)
  if not stat then
    uv.fs_close(fd)
    return
  end

  local data = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  if data then
    fd = uv.fs_open(OUTPUT, "w", Util.fmode("664"))
    if fd then
      uv.fs_write(fd, ("%s%s%s"):format(data, data ~= "" and "\n" or "", msg))
      uv.fs_close(fd)
    end
  end
end

---@class LspFileOps.Log
---@field level "debug"|"info"|"error"|"warn"
local M = {}

M.level = "error"

---@param level "debug"|"info"|"error"|"warn"
---@return fun(...: any) cb
local function gen_log_func(level)
  Util.validate({ level = { level, { "string" } } })

  return function(...)
    local msg = ""
    for i = 1, select("#", ...) do
      local arg = select(i, ...)
      msg = ("%s %s"):format(
        msg,
        arg == nil and "nil"
          or (
            type(arg) == "string" and arg
            or (
              (type(arg) == "number" or type(arg) == "boolean") and tostring(arg)
              or vim.inspect(arg, { newline = " ", indent = "" })
            )
          )
      )
    end

    if msg ~= "" then -- NOTE: Avoid notifying on empty output
      vim.schedule(function() -- HACK: Use `vim.schedule()` to avoid mangling the output of tests
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
        if levels[M.level] <= levels[level] then
          vim.notify(txt, levels[level])
        end
        write_output(txt)
      end)
    end
  end
end

M.debug = gen_log_func("debug")
M.error = gen_log_func("error")
M.info = gen_log_func("info")
M.warn = gen_log_func("warn")

function M.setup()
  if timer then
    return
  end

  timer = uv.new_timer()
  if timer then
    timer:start(30000, 30000, function()
      local stat = uv.fs_stat(OUTPUT)
      if stat and stat.size > MAX_SIZE then
        local fd = uv.fs_open(OUTPUT, "w", Util.fmode("644"))
        if fd then
          uv.fs_ftruncate(fd, 0)
          uv.fs_close(fd)
        end
      end
    end)

    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("LFOTimer", { clear = true }),
      once = true,
      callback = function()
        if timer then
          timer:stop()
          timer = nil
        end
      end,
    })
  end
end

return M
