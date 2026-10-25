local assert = require("luassert") --[[@as Luassert]]

describe("create", function()
  local lfo ---@type LFO

  before_each(function()
    package.loaded["lsp-file-operations"] = nil
    package.loaded["lsp-file-operations.config"] = nil
    package.loaded["lsp-file-operations.log"] = nil
    package.loaded["lsp-file-operations.util"] = nil

    lfo = require("lsp-file-operations")
    lfo.setup()
  end)

  it("creates a file when its parent directories do not exist", function()
    local root = vim.fn.tempname()
    local target = vim.fs.joinpath(root, "nested", "file.lua")

    local call_ok, result = pcall(lfo.create, target)
    assert.is_true(call_ok)
    assert.is_true(result)
    assert.is_true(vim.fn.filereadable(target) == 1)

    vim.fn.delete(root, "rf")
  end)
end)
