local utils = require("lsp-file-operations.utils")
local assert = require("luassert")

describe("utils.validate", function()
  it("accepts valid values", function()
    assert.has_no.errors(function()
      utils.validate({ name = { "foo", { "string" } } })
    end)
  end)

  it("rejects wrong types", function()
    assert.has.errors(function()
      utils.validate({ name = { 42, { "string" } } })
    end)
  end)

  it("respects the optional flag", function()
    assert.has_no.errors(function()
      utils.validate({ name = { nil, { "table", "nil" }, true } })
    end)
  end)

  it("rejects missing non-optional values", function()
    assert.has.errors(function()
      utils.validate({ name = { nil, { "string" } } })
    end)
  end)

  it("trims excess spec elements without error", function()
    assert.has_no.errors(function()
      utils.validate({ name = { "foo", { "string" }, false, "custom message" } })
    end)
  end)
end)

describe("utils.get_nested_path", function()
  local t = { a = { b = { c = "value" } } }

  it("resolves a deep path", function()
    assert.are.equal("value", utils.get_nested_path(t, { "a", "b", "c" }))
  end)

  it("returns the table itself for empty keys", function()
    assert.are.same(t, utils.get_nested_path(t, {}))
  end)

  it("returns nil for a missing key", function()
    assert.is_nil(utils.get_nested_path(t, { "a", "x", "c" }))
  end)
end)

describe("utils.matches_filters", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("matches a file glob", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    vim.fn.writefile({}, file)
    assert.is_true(utils.matches_filters({ { pattern = { glob = "**/*.lua" } } }, file))
  end)

  it("does not match a non-matching glob", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    vim.fn.writefile({}, file)
    assert.is_falsy(utils.matches_filters({ { pattern = { glob = "**/*.py" } } }, file))
  end)

  it("respects matches = 'file' (excludes directories)", function()
    assert.is_falsy(
      utils.matches_filters({ { pattern = { glob = "**/*", matches = "file" } } }, tmpdir)
    )
  end)

  it("respects matches = 'folder' (excludes files)", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    vim.fn.writefile({}, file)
    assert.is_falsy(
      utils.matches_filters({ { pattern = { glob = "**/*", matches = "folder" } } }, file)
    )
  end)

  it("honors ignoreCase option", function()
    local file = vim.fs.joinpath(tmpdir, "Test.LUA")
    vim.fn.writefile({}, file)
    assert.is_true(
      utils.matches_filters(
        { { pattern = { glob = "**/*.lua", options = { ignoreCase = true } } } },
        file
      )
    )
  end)

  it("returns falsy for an empty filter list", function()
    assert.is_falsy(utils.matches_filters({}, tmpdir))
  end)

  it("matches if ANY filter matches (OR semantics)", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    vim.fn.writefile({}, file)
    assert.is_true(utils.matches_filters({
      { pattern = { glob = "**/*.py" } },
      { pattern = { glob = "**/*.lua" } },
    }, file))
  end)

  it("matches directory globs like '**/' against folders only", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    vim.fn.writefile({}, file)
    local filters = { { pattern = { glob = "**/" } } }
    assert.is_true(utils.matches_filters(filters, tmpdir))
    assert.is_falsy(utils.matches_filters(filters, file))
  end)

  it("restores the global ignorecase option after matching", function()
    vim.o.ignorecase = true
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    vim.fn.writefile({}, file)
    utils.matches_filters({ { pattern = { glob = "**/*.lua" } } }, file)
    assert.is_true(vim.o.ignorecase)
    vim.o.ignorecase = false
  end)
end)
