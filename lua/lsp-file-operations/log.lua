---@alias LFO.Log.LogLevels "debug"|"info"|"error"|"warn"

local MAX_SIZE = 1048576 -- 1MiB
local OUTPUT = vim.fs.joinpath(vim.fn.stdpath("cache"), "lsp-file-operations.log")
local uv = vim.uv or vim.loop
local Util = require("lsp-file-operations.util")

---@enum LFO.LogLevelEnum
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
    fd = assert(uv.fs_open(OUTPUT, "w", Util.fmode("644")), "Unable to open file to create logfile")
    assert(uv.fs_close(fd), "Unable to close file descriptor for logfile")
  end

  fd = assert(
    uv.fs_open(OUTPUT, "r", Util.fmode("644")),
    "Unable to open logfile file to read its contents"
  )
  stat = uv.fs_stat(OUTPUT)
  local data = nil ---@type string|nil|?
  if stat then
    data = assert(uv.fs_read(fd, stat.size), "Unable to read data from logfile")
  end
  assert(uv.fs_close(fd), "Unable to close file descriptor for logfile")

  if data then
    fd = assert(uv.fs_open(OUTPUT, "w", Util.fmode("664")), "Unable to open logfile for writing")
    assert(
      uv.fs_write(fd, ("%s%s%s"):format(data, data ~= "" and "\n" or "", msg)),
      "Unable to write data to logfile"
    )
    assert(uv.fs_close(fd), "Unable to close file descriptor for logfile")
  end
end

local level = "error" ---@type LFO.Log.LogLevels

---@class LFO.Log
---@field level LFO.Log.LogLevels
local M = {}

---@param lvl LFO.Log.LogLevels
function M.set_level(lvl)
  Util.validate({ lvl = { lvl, { "string" } } })

  assert(vim.list_contains({ "debug", "error", "info", "warn" }, lvl), "Level is not valid")
  level = lvl
end

---@param lvl LFO.Log.LogLevels
---@param notify boolean
---@return fun(...: any) cb
---@overload fun(lvl: LFO.Log.LogLevels): cb: fun(...: any)
local function gen_log_func(lvl, notify)
  Util.validate({
    lvl = { lvl, { "string" } },
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
              (type(arg) == "boolean" or type(arg) == "number") and tostring(arg)
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
        lvl:upper(),
        date.year,
        date.month,
        date.day,
        date.hour,
        date.min,
        date.sec,
        msg
      )

      write_output(txt)

      if levels[level] <= levels[lvl] or notify then
        vim.notify(txt, levels[lvl])
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
    local stat = assert(uv.fs_stat(OUTPUT), "Unable to retrieve stats from logfile")
    if stat.size > MAX_SIZE then
      local fd = assert(uv.fs_open(OUTPUT, "w", Util.fmode("644")), "Unable to open logfile")
      assert(uv.fs_ftruncate(fd, 0), "Logfile could not be truncated")
      assert(uv.fs_close(fd), "Unable to close file descriptor for logfile")
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
