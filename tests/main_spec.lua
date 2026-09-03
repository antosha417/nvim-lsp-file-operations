local lfo = require("lsp-file-operations")

describe("lsp-file-operations", function()
  describe("default_capabilities", function()
    local saved_config

    before_each(function()
      saved_config = lfo.config
    end)

    after_each(function()
      lfo.config = saved_config
    end)

    it("enables all six file operations by default (before setup)", function()
      lfo.config = nil
      local caps = lfo.default_capabilities()
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
      }, caps)
    end)

    it("reflects operations disabled in the config", function()
      lfo.config = {
        operations = {
          didCreateFiles = true,
          didDeleteFiles = true,
          didRenameFiles = true,
          willCreateFiles = true,
          willDeleteFiles = true,
          willRenameFiles = false,
        },
      }
      local caps = lfo.default_capabilities()
      assert.is_false(caps.workspace.fileOperations.willRename)
      assert.is_true(caps.workspace.fileOperations.didCreate)
    end)
  end)
end)
