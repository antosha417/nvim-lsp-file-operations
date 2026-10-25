local assert = require("luassert")
local uv = vim.uv or vim.loop

describe("Util.validate", function()
  local Util ---@type LFO.Util

  before_each(function()
    package.loaded["lsp-file-operations.util"] = nil
    Util = require("lsp-file-operations.util")
  end)

  it("accepts valid values", function()
    assert.has_no.errors(function()
      Util.validate({ name = { "foo", { "string" } } })
    end)
  end)

  it("rejects wrong types", function()
    assert.has.errors(function()
      Util.validate({ name = { 42, { "string" } } })
    end)
  end)

  it("accepts nil value when only optional flag set to true", function()
    assert.has_no.errors(function()
      Util.validate({ name = { nil, { "table" }, true } })
    end)
  end)

  it("respects the optional flag", function()
    assert.has_no.errors(function()
      Util.validate({ name = { nil, { "table", "nil" }, true } })
    end)
  end)

  it("rejects missing non-optional values", function()
    assert.has.errors(function()
      Util.validate({ name = { nil, { "string" } } })
    end)
  end)

  it("trims excess spec elements without error", function()
    assert.has_no.errors(function()
      Util.validate({ name = { "foo", { "string" }, false, "custom message" } })
    end)
  end)
end)

describe("Util.get_nested_path", function()
  local t ---@type table
  local Util ---@type LFO.Util

  before_each(function()
    t = { a = { b = { c = "value" } } }

    package.loaded["lsp-file-operations.util"] = nil
    Util = require("lsp-file-operations.util")
  end)

  it("resolves a deep path", function()
    assert.are.equal("value", Util.get_nested_path(t, { "a", "b", "c" }))
  end)

  it("returns the table itself for empty keys", function()
    assert.are.same(t, Util.get_nested_path(t, {}))
  end)

  it("returns nil for a missing key", function()
    assert.is_nil(Util.get_nested_path(t, { "a", "x", "c" }))
  end)
end)

describe("Util.matches_filters", function()
  local tmpdir ---@type string
  local Util ---@type LFO.Util

  before_each(function()
    package.loaded["lsp-file-operations.util"] = nil

    Util = require("lsp-file-operations.util")
    tmpdir = vim.fn.tempname()
    if vim.fn.has("nvim-0.13") == 1 then
      vim.fs.mkdir(tmpdir, { parents = true })
    else
      vim.fn.mkdir(tmpdir, "p")
    end
  end)

  after_each(function()
    if vim.fn.has("nvim-0.13") == 1 then
      vim.fs.rm(tmpdir, { force = true, recursive = true })
    else
      vim.fn.delete(tmpdir, "rf")
    end
  end)

  it("matches a file glob", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))
    assert.is_true(Util.matches_filters({ { pattern = { glob = "**/*.lua" } } }, file))
  end)

  it("does not match a non-matching glob", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))
    assert.is_falsy(Util.matches_filters({ { pattern = { glob = "**/*.py" } } }, file))
  end)

  it("respects matches = 'file' (excludes directories)", function()
    assert.is_falsy(
      Util.matches_filters({ { pattern = { glob = "**/*", matches = "file" } } }, tmpdir)
    )
  end)

  it("respects matches = 'folder' (excludes files)", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))
    assert.is_falsy(
      Util.matches_filters({ { pattern = { glob = "**/*", matches = "folder" } } }, file)
    )
  end)

  it("honors ignoreCase option", function()
    local file = vim.fs.joinpath(tmpdir, "Test.LUA")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))
    assert.is_true(
      Util.matches_filters(
        { { pattern = { glob = "**/*.lua", options = { ignoreCase = true } } } },
        file
      )
    )
  end)

  it("returns falsy for an empty filter list", function()
    assert.is_falsy(Util.matches_filters({}, tmpdir))
  end)

  it("matches if ANY filter matches (OR semantics)", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))
    assert.is_true(Util.matches_filters({
      { pattern = { glob = "**/*.py" } },
      { pattern = { glob = "**/*.lua" } },
    }, file))
  end)

  it("matches directory globs like '**/' against folders only", function()
    local file = vim.fs.joinpath(tmpdir, "test.lua")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))

    local filters = { { pattern = { glob = "**/" } } }
    assert.is_true(Util.matches_filters(filters, tmpdir))
    assert.is_falsy(Util.matches_filters(filters, file))
  end)

  it("restores the global ignorecase option after matching", function()
    vim.o.ignorecase = true

    local file = vim.fs.joinpath(tmpdir, "test.lua")
    local fd = assert(
      uv.fs_open(file, "w", tonumber("644", 8)),
      ("Unable to open `%s` to write"):format(file)
    )
    assert(uv.fs_write(fd, { "" }), ("Unable to write to `%s`"):format(file))
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(file))

    Util.matches_filters({ { pattern = { glob = "**/*.lua" } } }, file)
    assert.is_true(vim.o.ignorecase)
    vim.o.ignorecase = false
  end)
end)
