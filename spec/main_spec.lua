local assert = require("luassert") --[[@as Luassert]]

describe("lsp-file-operations", function()
  describe("default_capabilities", function()
    local saved_config ---@type LFOConfig
    local lfo ---@type LFO

    before_each(function()
      package.loaded["lsp-file-operations"] = nil
      package.loaded["lsp-file-operations.config"] = nil
      package.loaded["lsp-file-operations.log"] = nil
      package.loaded["lsp-file-operations.util"] = nil

      lfo = require("lsp-file-operations")
      lfo.setup()
      saved_config = lfo.get_config()
    end)

    after_each(function()
      lfo.set_config(saved_config)
    end)

    it("enables all six file operations by default (before setup)", function()
      lfo.set_config()
      assert.are.same({
        workspace = {
          fileOperations = {
            didCreate = true,
            didDelete = true,
            didRename = true,
            willCreate = true,
            willDelete = true,
            willRename = true,
          },
        },
      }, lfo.default_capabilities())
    end)

    it("reflects operations disabled in the config", function()
      lfo.set_config({
        operations = {
          didCreateFiles = true,
          didDeleteFiles = true,
          didRenameFiles = true,
          willCreateFiles = true,
          willDeleteFiles = true,
          willRenameFiles = false,
        },
      })
      local caps = lfo.default_capabilities()
      assert.is_false(caps.workspace.fileOperations.willRename)
      assert.is_true(caps.workspace.fileOperations.didCreate)
    end)
  end)
end)
