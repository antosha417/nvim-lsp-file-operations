---@module "lsp-file-operations._meta"

local Config = require("lsp-file-operations.config")
local Utils = require("lsp-file-operations.utils")
local Log = require("lsp-file-operations.log")

---@param bufnr integer
---@param old_name string
---@param new_name string
local function rename_buf(bufnr, old_name, new_name)
  Utils.validate({
    bufnr = { bufnr, { "number" } },
    old_name = { old_name, { "string" } },
    new_name = { new_name, { "string" } },
  })

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == old_name then
    vim.api.nvim_buf_set_name(bufnr, new_name)
    vim.api.nvim_buf_call(bufnr, function()
      pcall(vim.cmd.edit, { bang = true, mods = { silent = true } })
    end)
  end
end

---@overload fun(method: "didCreate"|"didDelete"|"willCreate"|"willDelete"): callback: fun(data: { fname: string })
---@overload fun(method: "didRename"|"willRename"): callback: fun(data: { new_name: string, old_name: string })
local function gen_callback(method)
  if vim.list_contains({ "didCreate", "didDelete" }, method) then
    ---@param data { fname: string }
    return function(data)
      Utils.validate({
        data = { data, { "table" } },
        ["data.fname"] = { data.fname, { "string" } },
      })

      local lsp_method = ("workspace/%sFiles"):format(method)
      for _, client in ipairs(Utils.get_clients()) do
        if client.initialized then
          local cap = Utils.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Utils.matches_filters(cap.filters or {}, data.fname) then
            local params = { files = { { uri = vim.uri_from_fname(data.fname) } } }
            Utils.client_notify(client, lsp_method, params)
            require("lsp-file-operations.log").debug(
              ("Sending %s notification"):format(lsp_method),
              params
            )
          end
        end
      end
    end
  elseif method == "didRename" then
    ---@param data { new_name: string, old_name: string }
    return function(data)
      Utils.validate({
        data = { data, { "table" } },
        ["data.new_name"] = { data.new_name, { "string" } },
        ["data.old_name"] = { data.old_name, { "string" } },
      })

      local old, new = data.old_name, data.new_name
      local lsp_method = ("workspace/%sFiles"):format(method)
      for _, client in ipairs(Utils.get_clients()) do
        if client.initialized then
          local cap = Utils.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Utils.matches_filters(cap.filters or {}, old) then
            local params = {
              files = { { newUri = vim.uri_from_fname(new), oldUri = vim.uri_from_fname(old) } },
            }
            Utils.client_notify(client, lsp_method, params)
            require("lsp-file-operations.log").debug(
              ("Sending %s notification"):format(lsp_method),
              params
            )
          end
        end
      end
    end
  elseif vim.list_contains({ "willCreate", "willDelete" }, method) then
    ---@param data { fname: string }
    return function(data)
      Utils.validate({
        data = { data, { "table" } },
        ["data.fname"] = { data.fname, { "string" } },
      })

      for _, client in ipairs(Utils.get_clients()) do
        if client.initialized then
          local cap = Utils.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Utils.matches_filters(cap.filters or {}, data.fname) then
            local edit, mtd =
              Utils.get_workspace_edit(("%sFiles"):format(method), client, data.fname)
            if edit and mtd then
              require("lsp-file-operations.log").debug(("Applying %s edit"):format(mtd), edit)
              vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
            end
          end
        end
      end
    end
  elseif method == "willRename" then
    ---@param data { new_name: string, old_name: string }
    return function(data)
      Utils.validate({
        data = { data, { "table" } },
        ["data.new_name"] = { data.new_name, { "string" } },
        ["data.old_name"] = { data.old_name, { "string" } },
      })

      local old, new = data.old_name, data.new_name
      for _, client in ipairs(Utils.get_clients()) do
        if client.initialized then
          local cap = Utils.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Utils.matches_filters(cap.filters or {}, old) then
            local edit, mtd = Utils.get_workspace_edit("willRenameFiles", client, old, new)
            if edit and mtd then
              require("lsp-file-operations.log").debug(("Applying %s edit"):format(mtd), edit)
              vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
            end
          end
        end
      end
    end
  end
end

---@param bufnr integer
---@param fname string
local function delete_buf(bufnr, fname)
  Utils.validate({
    bufnr = { bufnr, { "number" } },
    fname = { fname, { "string" } },
  })

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == fname then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

---@class LspFileOps
local M = {}

M.get_config = Config.get
M.set_config = Config.set
M.setup = Config.setup

---The extra client capabilities provided by this plugin. To be merged with
---`vim.lsp.protocol.make_client_capabilities()` and sent to the LSP server.
---@return lsp.ClientCapabilities capabilities
function M.default_capabilities()
  local config = Config.get() or Config.get_defaults()
  local result = { workspace = { fileOperations = {} } } ---@type lsp.ClientCapabilities
  for operation, capability in pairs({
    didCreateFiles = "didCreate",
    didDeleteFiles = "didDelete",
    didRenameFiles = "didRename",
    willCreateFiles = "willCreate",
    willDeleteFiles = "willDelete",
    willRenameFiles = "willRename",
  }) do
    result.workspace.fileOperations[capability] = config.operations[operation]
  end
  return result
end

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---@param opts { new_name: string, old_name?: string }
---@return boolean success
function M.rename(opts)
  Utils.validate({
    opts = { opts, { "table" } },
    ["opts.new_name"] = { opts.new_name, { "string" } },
    ["opts.old_name"] = { opts.old_name, { "string", "nil" }, true },
  })
  local old_name = opts.old_name or vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local new_name = opts.new_name
  if new_name == "" or old_name == "" then
    Log.error("Either `new_name` or `old_name` for `rename()` are empty")
    error("Either `new_name` or `old_name` for `rename()` are empty")
  end
  old_name, new_name = vim.fn.fnamemodify(old_name, ":p"), vim.fn.fnamemodify(new_name, ":p")

  local ok, mod = pcall(require, "lsp-file-operations.will-rename")
  if not (ok and mod) then
    Log.error("Unable to find `lsp-file-operations.will-rename`!")
    error("Unable to find `lsp-file-operations.will-rename`!")
  end
  mod({ new_name = new_name, old_name = old_name })

  local dir = vim.fn.fnamemodify(new_name, ":h")
  if vim.fn.isdirectory(dir) ~= 1 then
    vim.fn.mkdir(dir, "p")
  end

  local rename_ok, rename_err = vim.uv.fs_rename(old_name, new_name)
  if not rename_ok then
    Log.error("Failed to rename:", rename_err)
    return false
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    rename_buf(bufnr, old_name, new_name)
  end

  ok, mod = pcall(require, "lsp-file-operations.did-rename")
  if not (ok and mod) then
    Log.error("Unable to find `lsp-file-operations.did-rename`!")
    return false
  end

  mod({ new_name = new_name, old_name = old_name })

  return true
end

M["did-create"] = gen_callback("didCreate")
M["did-delete"] = gen_callback("didDelete")
M["did-rename"] = gen_callback("didRename")
M["will-create"] = gen_callback("willCreate")
M["will-delete"] = gen_callback("willDelete")
M["will-rename"] = gen_callback("willRename")

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---@param opts { fname: string }
---@return boolean success
function M.delete(opts)
  Utils.validate({
    opts = { opts, { "table" } },
    ["opts.fname"] = { opts.fname, { "string" } },
  })
  if opts.fname == "" then
    return false
  end

  local fname = vim.fn.fnamemodify(opts.fname, ":p")
  local stat = vim.uv.fs_stat(fname)
  if not stat then
    return false
  end

  local ok, mod = pcall(require, "lsp-file-operations.will-delete")
  if not (ok and mod) then
    return false
  end

  mod({ fname = fname })

  local rm_ok, rm_err = (stat.type == "directory" and vim.uv.fs_rmdir or vim.uv.fs_unlink)(fname)
  if not rm_ok then
    Log.error("Failed to delete:", rm_err)
    return false
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    delete_buf(bufnr, fname)
  end

  ok, mod = pcall(require, "lsp-file-operations.did-delete")
  if not (ok and mod) then
    return false
  end

  mod({ fname = fname })

  return true
end

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---@param opts { fname: string }
---@return boolean success
function M.create(opts)
  Utils.validate({
    opts = { opts, { "table" } },
    ["opts.fname"] = { opts.fname, { "string" } },
  })
  if opts.fname == "" then
    return false
  end

  local fname = vim.fn.fnamemodify(opts.fname, ":p")
  local ok, mod = pcall(require, "lsp-file-operations.will-create")
  if not (ok and mod) then
    return false
  end

  mod({ fname = fname })

  local dir = vim.fn.fnamemodify(fname, ":h")
  if vim.fn.isdirectory(dir) ~= 1 then
    vim.fn.mkdir(dir, "p")
  end

  local fd, err = vim.uv.fs_open(fname, "w", tonumber("644", 8))
  if not fd then
    Log.error("Failed to create:", err)
    return false
  end
  vim.uv.fs_close(fd)

  ok, mod = pcall(require, "lsp-file-operations.did-create")
  if not (ok and mod) then
    return false
  end

  mod({ fname = fname })

  return (pcall(vim.cmd.edit, vim.fn.fnameescape(fname)))
end

local LFO = setmetatable(M, {
  __index = function(self, k)
    local raw = rawget(self, k) or nil
    if raw ~= nil then
      return raw
    end

    local ok_mod, mod = pcall(require, "lsp-file-operations." .. k)
    if ok_mod and mod then
      return Utils.rawset(self, k, mod)
    end

    if k == "didCreate" then
      return Utils.rawset(self, k, require("lsp-file-operations.did-create"))
    end
    if k == "didRDelete" then
      return Utils.rawset(self, k, require("lsp-file-operations.did-delete"))
    end
    if k == "didRename" then
      return Utils.rawset(self, k, require("lsp-file-operations.did-rename"))
    end
    if k == "willCreate" then
      return Utils.rawset(self, k, require("lsp-file-operations.will-create"))
    end
    if k == "willRDelete" then
      return Utils.rawset(self, k, require("lsp-file-operations.will-delete"))
    end
    if k == "willRename" then
      return Utils.rawset(self, k, require("lsp-file-operations.will-rename"))
    end
  end,
})

return LFO
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
