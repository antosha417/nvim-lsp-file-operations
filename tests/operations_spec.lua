local utils = require("lsp-file-operations.utils")
local stub = require("luassert.stub")

--- Build a fake LSP client.
---@param cap_key string|nil capability key under workspace.fileOperations (e.g. "didCreate")
---@param filters table|nil FileOperationFilter[] for the capability
---@param response table|nil what request_sync should return (for will-* operations)
local function make_client(cap_key, filters, response)
  local client = {
    initialized = true,
    offset_encoding = "utf-16",
    server_capabilities = { workspace = { fileOperations = {} } },
    notify_calls = {},
    request_calls = {},
    response = response,
  }
  if cap_key then
    client.server_capabilities.workspace.fileOperations[cap_key] =
      { filters = filters or { { pattern = { glob = "**/*.lua" } } } }
  end
  function client.notify(self, method, params)
    table.insert(self.notify_calls, { method = method, params = params })
  end
  function client.request_sync(method, params, timeout_ms)
    table.insert(
      client.request_calls,
      { method = method, params = params, timeout_ms = timeout_ms }
    )
    if client.response and client.response.err then
      error(client.response.err)
    end
    return client.response
  end
  return client
end

--- Run one of the will-*/did-* module callbacks against the given fake clients.
local function run_with_clients(module_name, clients, data)
  local get_clients = stub(utils, "get_clients").returns(clients)
  local ok, err = pcall(require(module_name).callback, data)
  get_clients:revert()
  assert(ok, err)
end

describe("did-* operations", function()
  local fname = vim.fn.tempname() .. "/test.lua"

  for _, case in ipairs({
    { module = "did-create", cap = "didCreate", method = "workspace/didCreateFiles" },
    { module = "did-delete", cap = "didDelete", method = "workspace/didDeleteFiles" },
  }) do
    describe(case.module, function()
      local mod = "lsp-file-operations." .. case.module

      it("notifies clients that support the capability", function()
        local client = make_client(case.cap)
        run_with_clients(mod, { client }, { fname = fname })
        assert.are.equal(1, #client.notify_calls)
        assert.are.equal(case.method, client.notify_calls[1].method)
        assert.are.same(
          { files = { { uri = vim.uri_from_fname(fname) } } },
          client.notify_calls[1].params
        )
      end)

      it("does not notify clients lacking the capability", function()
        local client = make_client(nil)
        run_with_clients(mod, { client }, { fname = fname })
        assert.are.equal(0, #client.notify_calls)
      end)

      it("does not notify when the file does not match the filters", function()
        local client = make_client(case.cap, { { pattern = { glob = "**/*.py" } } })
        run_with_clients(mod, { client }, { fname = fname })
        assert.are.equal(0, #client.notify_calls)
      end)

      it("skips uninitialized clients", function()
        local client = make_client(case.cap)
        client.initialized = false
        run_with_clients(mod, { client }, { fname = fname })
        assert.are.equal(0, #client.notify_calls)
      end)
    end)
  end

  describe("did-rename", function()
    local old_name = fname
    local new_name = fname .. ".bak"

    it("sends oldUri and newUri", function()
      local client = make_client("didRename")
      run_with_clients(
        "lsp-file-operations.did-rename",
        { client },
        { old_name = old_name, new_name = new_name }
      )
      assert.are.equal(1, #client.notify_calls)
      assert.are.equal("workspace/didRenameFiles", client.notify_calls[1].method)
      assert.are.same({
        files = { { oldUri = vim.uri_from_fname(old_name), newUri = vim.uri_from_fname(new_name) } },
      }, client.notify_calls[1].params)
    end)

    it("does not notify clients lacking the capability", function()
      local client = make_client(nil)
      run_with_clients(
        "lsp-file-operations.did-rename",
        { client },
        { old_name = old_name, new_name = new_name }
      )
      assert.are.equal(0, #client.notify_calls)
    end)

    it("matches filters against the old name", function()
      local client = make_client("didRename", { { pattern = { glob = "**/*.py" } } })
      run_with_clients(
        "lsp-file-operations.did-rename",
        { client },
        { old_name = old_name, new_name = new_name }
      )
      assert.are.equal(0, #client.notify_calls)
    end)
  end)
end)

describe("will-* operations", function()
  local fname = vim.fn.tempname() .. "/test.lua"
  local edit = { changes = { ["file:///dummy"] = {} } }

  before_each(function()
    require("lsp-file-operations").config = { timeout_ms = 1000 }
  end)

  for _, case in ipairs({
    { module = "will-create", cap = "willCreate", method = "workspace/willCreateFiles" },
    { module = "will-delete", cap = "willDelete", method = "workspace/willDeleteFiles" },
  }) do
    describe(case.module, function()
      local mod = "lsp-file-operations." .. case.module

      it("requests an edit and applies it", function()
        local client = make_client(case.cap, nil, { result = edit })
        local apply = stub(vim.lsp.util, "apply_workspace_edit")
        run_with_clients(mod, { client }, { fname = fname })
        assert.are.equal(1, #client.request_calls)
        assert.are.equal(case.method, client.request_calls[1].method)
        assert.are.same(
          { files = { { uri = vim.uri_from_fname(fname) } } },
          client.request_calls[1].params
        )
        assert.stub(apply).was.called_with(edit, "utf-16")
        apply:revert()
      end)

      it("does not request from clients lacking the capability", function()
        local client = make_client(nil, nil, { result = edit })
        run_with_clients(mod, { client }, { fname = fname })
        assert.are.equal(0, #client.request_calls)
      end)

      it("does not apply an edit when the request errors", function()
        local client = make_client(case.cap, nil, { err = "boom" })
        local apply = stub(vim.lsp.util, "apply_workspace_edit")
        run_with_clients(mod, { client }, { fname = fname })
        assert.stub(apply).was.not_called()
        apply:revert()
      end)

      it("does not apply an edit on an empty response (timeout)", function()
        local client = make_client(case.cap, nil, nil)
        local apply = stub(vim.lsp.util, "apply_workspace_edit")
        run_with_clients(mod, { client }, { fname = fname })
        assert.stub(apply).was.not_called()
        apply:revert()
      end)
    end)
  end

  describe("will-rename", function()
    local old_name = fname
    local new_name = fname .. ".bak"

    it("sends oldUri and newUri and applies the edit", function()
      local client = make_client("willRename", nil, { result = edit })
      local apply = stub(vim.lsp.util, "apply_workspace_edit")
      run_with_clients(
        "lsp-file-operations.will-rename",
        { client },
        { old_name = old_name, new_name = new_name }
      )
      assert.are.equal(1, #client.request_calls)
      assert.are.equal("workspace/willRenameFiles", client.request_calls[1].method)
      assert.are.same({
        files = { { oldUri = vim.uri_from_fname(old_name), newUri = vim.uri_from_fname(new_name) } },
      }, client.request_calls[1].params)
      assert.stub(apply).was.called_with(edit, "utf-16")
      apply:revert()
    end)

    it("does not apply an edit when the request errors", function()
      local client = make_client("willRename", nil, { err = "boom" })
      local apply = stub(vim.lsp.util, "apply_workspace_edit")
      run_with_clients(
        "lsp-file-operations.will-rename",
        { client },
        { old_name = old_name, new_name = new_name }
      )
      assert.stub(apply).was.not_called()
      apply:revert()
    end)
  end)
end)
