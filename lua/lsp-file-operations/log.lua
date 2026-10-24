---@alias LspFileOps.Log.LogLevels "debug"|"info"|"error"|"warn"

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
    fd = assert(
      uv.fs_open(OUTPUT, "w", Util.fmode("644")),
      ("Unable to open file to create: %s"):format(OUTPUT)
    )
    assert(uv.fs_close(fd), ("Unable to close file descriptor for %s"):format(OUTPUT))
  end

  fd = assert(
    uv.fs_open(OUTPUT, "r", Util.fmode("644")),
    ("Unable to open file to read its contents: %s"):format(OUTPUT)
  )
  stat = uv.fs_stat(OUTPUT)
  local data = nil ---@type string|nil|?
  if stat then
    data = uv.fs_read(fd, stat.size)
  end
  assert(uv.fs_close(fd), ("Unable to close file descriptor for %s"):format(OUTPUT))

  if data then
    fd = assert(
      uv.fs_open(OUTPUT, "w", Util.fmode("664")),
      ("Unable to open file to write: %s"):format(OUTPUT)
    )
    assert(
      uv.fs_write(fd, ("%s%s%s"):format(data, data ~= "" and "\n" or "", msg)),
      ("Unable to write contents to %s"):format(OUTPUT)
    )
    assert(uv.fs_close(fd), ("Unable to close file descriptor for %s"):format(OUTPUT))
  end
end

---@class LspFileOps.Log
---@field level LspFileOps.Log.LogLevels
local M = {}

M.level = "error"

---@param level LspFileOps.Log.LogLevels
---@param notify boolean
---@return fun(...: any) cb
---@overload fun(level: LspFileOps.Log.LogLevels): cb: fun(...: any)
local function gen_log_func(level, notify)
  Util.validate({
    level = { level, { "string" } },
    notify = { notify, { "boolean", "nil" }, true },
  })
  if notify == nil then
    notify = false
  end

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
              vim.list_contains({ "number", "boolean" }, type(arg)) and tostring(arg)
              or vim.inspect(arg, { newline = " ", indent = "" })
            )
          )
      )
    end

    if msg == "" then -- NOTE: Avoid notifying on empty output
      return
    end

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

      write_output(txt)

      if levels[M.level] <= levels[level] or notify then
        vim.notify(txt, levels[level])
      end
    end)
  end
end

M.debug = gen_log_func("debug")
M.error = gen_log_func("error")
M.info = gen_log_func("info")
M.notify_debug = gen_log_func("debug", true)
M.notify_error = gen_log_func("error", true)
M.notify_info = gen_log_func("info", true)
M.notify_warn = gen_log_func("warn", true)
M.warn = gen_log_func("warn")

function M.setup()
  if timer then
    return
  end

  timer = assert(uv.new_timer(), "Unable to create new timer")
  timer:start(30000, 30000, function()
    local stat = uv.fs_stat(OUTPUT)
    if stat and stat.size > MAX_SIZE then
      local fd = uv.fs_open(OUTPUT, "w", Util.fmode("644"))
      if fd then
        assert(uv.fs_ftruncate(fd, 0), ("Log file could not be truncated: %s"):format(OUTPUT))
        assert(uv.fs_close(fd), ("Unable to close file descriptor for %s"):format(OUTPUT))
      end
    end
  end)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("LFOTimer", { clear = true }),
    once = true,
    callback = function()
      if timer then
        assert(timer:stop(), "Unable to stop log timer")
        timer = nil
      end
    end,
  })

  vim.g.lfo_log_setup = 1
end

return M
