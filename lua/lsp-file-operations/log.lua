---@alias LFO.Log.LogLevels "debug"|"info"|"error"|"warn"

local MAX_SIZE = 1048576 -- 1MiB
local OUTPUT = vim.fs.joinpath(vim.fn.stdpath("cache"), "lsp-file-operations", "log")
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
  if stat then
    assert(stat.type ~= "directory", ("Log file is a directory: `%s`"):format(OUTPUT))
  end

  local fd ---@type integer|nil|?
  if not stat then
    local parent = Util.strip_slash(OUTPUT, ":h")
    if Util.vim_has("nvim-0.13") then
      vim.fs.mkdir(parent, { parents = true, mode = Util.fmode("755") })
    else
      assert(
        vim.fn.mkdir(parent, "p") == 1,
        ("Unable to create parent directories for log file: `%s`"):format(parent)
      )
    end

    fd =
      assert(uv.fs_open(OUTPUT, "w", Util.fmode("644")), "Unable to open file to create log file")
    assert(uv.fs_close(fd), "Unable to close file descriptor for log file")
  end

  fd = assert(
    uv.fs_open(OUTPUT, "r", Util.fmode("644")),
    "Unable to open log file file to read its contents"
  )
  stat = uv.fs_stat(OUTPUT)
  local data = nil ---@type string|nil|?
  if stat then
    data = assert(uv.fs_read(fd, stat.size), "Unable to read data from log file")
  end
  assert(uv.fs_close(fd), "Unable to close file descriptor for log file")

  if data then
    fd = assert(uv.fs_open(OUTPUT, "w", Util.fmode("664")), "Unable to open log file for writing")
    assert(
      uv.fs_write(fd, ("%s%s%s"):format(data, data ~= "" and "\n" or "", msg)),
      "Unable to write data to log file"
    )
    assert(uv.fs_close(fd), "Unable to close file descriptor for log file")
  end
end

local level = "error" ---@type LFO.Log.LogLevels
local log_tab = nil ---@type { tab: integer, buf: integer }|nil|?

---@class LFO.Log
local M = {}

function M.open()
  if log_tab then
    return
  end

  local stat = assert(uv.fs_stat(OUTPUT), "Unable to find log file")
  local fd = assert(uv.fs_open(OUTPUT, "r", Util.fmode("644")), "Unable to open log file")
  local data = assert(uv.fs_read(fd, stat.size), "Unable to read contents from log file")
  assert(uv.fs_close(fd), "Unable to close file descriptor for log file")

  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(data, "\n", { trimempty = false }))
  vim.api.nvim_buf_set_name(bufnr, "LFO Log")

  vim.bo[bufnr].ft = "log"
  vim.bo[bufnr].bt = "nofile"
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = false

  local tab = vim.api.nvim_open_tabpage(bufnr, true, { after = -1 })
  local win = vim.api.nvim_get_current_win()

  vim.wo[win].wrap = false
  vim.wo[win].list = false
  vim.wo[win].nu = false
  vim.wo[win].colorcolumn = ""
  vim.wo[win].foldenable = false
  vim.wo[win].signcolumn = "no"

  local group = vim.api.nvim_create_augroup("LFOLog", { clear = true })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = bufnr,
    callback = function()
      M.close()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      if #vim.api.nvim_list_tabpages() > 1 and vim.api.nvim_get_current_tabpage() == tab then
        pcall(vim.cmd.tabclose, { bang = true })
      end
    end,
  })

  vim.keymap.set("n", "q", M.close, { noremap = true })
  log_tab = { tab = tab, buf = bufnr }
end

function M.close()
  if not log_tab then
    return
  end

  pcall(vim.api.nvim_buf_delete, log_tab.buf, { force = true })
  log_tab = nil
end

function M.toggle()
  (log_tab and M.close or M.open)()
end

---@param lvl LFO.Log.LogLevels|1|2|3|4
function M.set_level(lvl)
  Util.validate({ lvl = { lvl, { "string", "number" } } })

  assert(
    vim.list_contains({ "debug", "error", "info", "warn", 1, 2, 3, 4 }, lvl),
    "Level is not valid"
  )

  if vim.list_contains({ 1, 2, 3, 4 }, lvl) then
    for k, v in pairs(levels) do
      if v == lvl then
        lvl = k
        break
      end
    end
  end
  level = lvl --[[@as LFO.Log.LogLevels]]
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

    msg = Util.lstrip(" ", msg)
    vim.schedule(function() -- HACK: Use `vim.schedule()` to avoid mangling the output of tests
      local date = os.date("*t") --[[@as osdate]]
      local txt = notify and ("[nvim-lsp-file-operations]: %s"):format(msg)
        or ("[nvim-lsp-file-operations] [%s %d-%d-%d %02d:%02d:%02d]: %s"):format(
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

---@param logfile string
---@overload fun()
function M.setup(logfile)
  Util.validate({ logfile = { logfile, { "string", "nil" }, true } })
  if timer then
    return
  end

  OUTPUT = logfile or OUTPUT

  timer = assert(uv.new_timer(), "Unable to create new timer")
  timer:start(30000, 30000, function()
    local stat = uv.fs_stat(OUTPUT)
    if stat and stat.size > MAX_SIZE then -- NOTE: Logfile is only created on first write
      assert(stat.type == "file", "Log file is not a file")
      local fd = assert(uv.fs_open(OUTPUT, "w", Util.fmode("644")), "Unable to open log file")
      assert(uv.fs_ftruncate(fd, 0), "Logfile could not be truncated")
      assert(uv.fs_close(fd), "Unable to close file descriptor for log file")
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
