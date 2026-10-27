local assert = require("luassert") --[[@as Luassert]]
local uv = vim.uv or vim.loop

describe("Log.setup", function()
  local cache_dir ---@type string
  local logfile ---@type string
  local tick ---@type fun()|nil
  local orig_stdpath = vim.fn.stdpath
  local orig_new_timer = uv.new_timer

  before_each(function()
    cache_dir = vim.fn.tempname()
    vim.fn.mkdir(cache_dir, "p")
    logfile = vim.fs.joinpath(cache_dir, "lsp-file-operations.log")

    vim.fn.stdpath = function(what) ---@diagnostic disable-line:duplicate-set-field
      return what == "cache" and cache_dir or orig_stdpath(what)
    end
    uv.new_timer = function() ---@diagnostic disable-line:duplicate-set-field
      return {
        start = function(_, _, _, cb)
          tick = cb
        end,
        stop = function()
          return 0
        end,
      }
    end

    package.loaded["lsp-file-operations.log"] = nil
    require("lsp-file-operations.log").setup()
  end)

  after_each(function()
    vim.fn.stdpath = orig_stdpath
    uv.new_timer = orig_new_timer
    tick = nil
    package.loaded["lsp-file-operations.log"] = nil
    vim.fn.delete(cache_dir, "rf")
  end)

  it("does not error when the logfile has not been created yet", function()
    assert.is_true(vim.fn.filereadable(logfile) == 0)
    assert.has_no.errors(tick)
  end)

  it("keeps a logfile under the size limit", function()
    vim.fn.writefile({ "entry" }, logfile)
    tick()
    assert.are.same({ "entry" }, vim.fn.readfile(logfile))
  end)

  it("truncates a logfile over the size limit", function()
    vim.fn.writefile({ ("x"):rep(1048577) }, logfile)
    tick()
    assert.are.equal(0, vim.fn.getfsize(logfile))
  end)
end)
