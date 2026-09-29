local assert = require("luassert") --[[@as Luassert]]

describe(":LFO user command", function()
  describe("is available", function()
    it("without setup", function()
      assert.is_function(vim.cmd.LFO)
    end)
    it("after setup", function()
      assert.is_true((pcall(require("lsp-file-operations").setup)))
      assert.is_function(vim.cmd.LFO)
    end)
  end)

  describe("will fail when", function()
    before_each(function()
      require("lsp-file-operations").setup()
    end)

    it("called without any arguments", function()
      assert.is_false((pcall(vim.cmd.LFO)))
    end)

    it("called with a bang", function()
      assert.is_false((pcall(vim.cmd.LFO, { bang = true })))
    end)

    it("create operation receives no arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "create" } })))
    end)

    it("create operation receives empty arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "create", "" } })))
    end)

    it("create operation receives more than one arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "create", "foo", "bar" } })))
    end)

    it("delete operation receives no arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "delete" } })))
    end)

    it("delete operation receives empty arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "delete", "" } })))
    end)

    it("delete operation receives more than one arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "delete", "foo", "bar" } })))
    end)

    it("rename operation receives no arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "rename" } })))
    end)

    it("rename operation receives an empty first argument", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "rename", "" } })))
    end)

    it("rename operation receives an empty second argument with a non-empty first one", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "rename", "" } })))
    end)

    it("rename operation receives more than two arguments", function()
      assert.is_false((pcall(vim.cmd.LFO, { args = { "rename", "foo", "bar", "baz" } })))
    end)
  end)
end)
