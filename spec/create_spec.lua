local lfo = require("lsp-file-operations")
local assert = require("luassert") --[[@as Luassert]]

describe("create", function()
  it("creates a file when its parent directories do not exist", function()
    local root = vim.fn.tempname()
    local target = vim.fs.joinpath(root, "nested", "file.lua")

    local call_ok, result = pcall(lfo.create, target)
    local file_exists = vim.fn.filereadable(target) == 1
    vim.fn.delete(root, "rf")

    assert.is_true(call_ok)
    assert.is_true(result)
    assert.is_true(file_exists)
  end)
end)
