---@module "lsp-file-operations._meta"

local uv = vim.uv or vim.loop
local Log = require("lsp-file-operations.log")
local Util = require("lsp-file-operations.util")

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

---@param path string
---@return boolean success
local function mkdir(path)
  Util.validate({ path = { path, { "string" } } })

  if vim.fn.has("nvim-0.13") == 1 then
    Log.debug("Neovim version >=v0.13.0, using `vim.fs.mkdir()`")
    return (pcall(vim.fs.mkdir, path, { parents = true }))
  end
  Log.debug("Neovim version <v0.13.0, using `vim.fn.mkdir()`")
  return vim.fn.mkdir(path, "p") == 1
end

---@class LspFileOps
---@field ["did-create"] fun(data: { fname: string })
---@field ["did-delete"] fun(data: { fname: string })
---@field ["did-rename"] fun(data: { new_name: string, old_name: string })
---@field ["will-create"] fun(data: { fname: string })
---@field ["will-delete"] fun(data: { fname: string })
---@field ["will-rename"] fun(data: { new_name: string, old_name: string })
---@field config LspFileOps.Config
---@field didCreate fun(data: { fname: string })
---@field didDelete fun(data: { fname: string })
---@field didRename fun(data: { new_name: string, old_name: string })
---@field did_create fun(data: { fname: string })
---@field did_delete fun(data: { fname: string })
---@field did_rename fun(data: { new_name: string, old_name: string })
---@field get_config fun(): config: LspFileOpsConfig
---@field log LspFileOps.Log
---@field set_config fun(cfg?: LspFileOpsConfig)
---@field util LspFileOps.Util
---@field willCreate fun(data: { fname: string })
---@field willDelete fun(data: { fname: string })
---@field willRename fun(data: { new_name: string, old_name: string })
---@field will_create fun(data: { fname: string })
---@field will_delete fun(data: { fname: string })
---@field will_rename fun(data: { new_name: string, old_name: string })
local M = {}

setmetatable(M, {
  __index = function(self, k) ---@param self LspFileOps
    local raw = Util.get(self, k)
    if raw ~= nil then
      return raw
    end

    local ok_mod, mod = pcall(require, "lsp-file-operations." .. k)
    if ok_mod and mod then
      return get(self, k, mod)
    end
    if k == "get_config" then
      return get(self, k, self.config.get)
    end
    if k == "set_config" then
      return get(self, k, self.config.set)
    end
    if k == "didCreate" then
      return get(self, k, self.did_create)
    end
    if k == "didDelete" then
      return get(self, k, self.did_delete)
    end
    if k == "didRename" then
      return get(self, k, self.did_rename)
    end
    if k == "did-create" then
      return get(self, k, self.did_create)
    end
    if k == "did-delete" then
      return get(self, k, self.did_delete)
    end
    if k == "did-rename" then
      return get(self, k, self.did_rename)
    end
    if k == "willCreate" then
      return get(self, k, self.will_create)
    end
    if k == "willDelete" then
      return get(self, k, self.will_delete)
    end
    if k == "willRename" then
      return get(self, k, self.will_rename)
    end
    if k == "will-create" then
      return get(self, k, self.will_create)
    end
    if k == "will-delete" then
      return get(self, k, self.will_delete)
    end
    if k == "will-rename" then
      return get(self, k, self.will_rename)
    end
  end,
})

---@param bufnr integer
---@param old_name string
---@param new_name string
local function rename_buf(bufnr, old_name, new_name)
  Util.validate({
    bufnr = { bufnr, { "number" } },
    old_name = { old_name, { "string" } },
    new_name = { new_name, { "string" } },
  })

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == old_name then
    vim.api.nvim_buf_set_name(bufnr, new_name)
    vim.api.nvim_buf_call(bufnr, function()
      pcall(vim.cmd.edit, { bang = true, mods = { silent = true } })
      if
        M.config.get().auto_save
        and vim.api.nvim_get_option_value("modified", { buf = bufnr })
      then
        pcall(vim.cmd.write)
      end
      vim.cmd.checktime()
    end)
  end
end

---@overload fun(method: "didCreate"|"didDelete"|"willCreate"|"willDelete"): callback: fun(data: { fname: string })
---@overload fun(method: "didRename"|"willRename"): callback: fun(data: { new_name: string, old_name: string })
local function gen_callback(method)
  local mtd = ("workspace/%sFiles"):format(method) --[[@as vim.lsp.protocol.Method]]
  if vim.list_contains({ "didCreate", "didDelete" }, method) then
    return function(data) ---@param data { fname: string }
      Util.validate({
        data = { data, { "table" } },
        ["data.fname"] = { data.fname, { "string" } },
      })

      for _, client in ipairs(Util.get_clients()) do
        if client.initialized then
          local cap = Util.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Util.matches_filters(cap.filters or {}, data.fname) then
            local params = { files = { { uri = vim.uri_from_fname(data.fname) } } }
            Util.client_notify(client, mtd, params)
            Log.debug(("Sending %s notification"):format(mtd), params)
          end
        end
      end
    end
  elseif method == "didRename" then
    return function(data) ---@param data { new_name: string, old_name: string }
      Util.validate({
        data = { data, { "table" } },
        ["data.new_name"] = { data.new_name, { "string" } },
        ["data.old_name"] = { data.old_name, { "string" } },
      })

      local old, new = data.old_name, data.new_name
      for _, client in ipairs(Util.get_clients()) do
        if client.initialized then
          local cap = Util.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Util.matches_filters(cap.filters or {}, old) then
            local params = {
              files = { { newUri = vim.uri_from_fname(new), oldUri = vim.uri_from_fname(old) } },
            }
            Util.client_notify(client, mtd, params)
            Log.debug(("Sending %s notification"):format(mtd), params)
          end
        end
      end
    end
  elseif vim.list_contains({ "willCreate", "willDelete" }, method) then
    return function(data) ---@param data { fname: string }
      Util.validate({
        data = { data, { "table" } },
        ["data.fname"] = { data.fname, { "string" } },
      })

      for _, client in ipairs(Util.get_clients()) do
        if client.initialized then
          local cap = Util.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Util.matches_filters(cap.filters or {}, data.fname) then
            local edit = Util.get_workspace_edit(("%sFiles"):format(method), client, data.fname)
            if edit then
              Util.client_apply_workspace_edit(client, mtd, edit)
            end
          end
        end
      end
    end
  elseif method == "willRename" then
    return function(data) ---@param data { new_name: string, old_name: string }
      Util.validate({
        data = { data, { "table" } },
        ["data.new_name"] = { data.new_name, { "string" } },
        ["data.old_name"] = { data.old_name, { "string" } },
      })

      local old, new = data.old_name, data.new_name
      for _, client in ipairs(Util.get_clients()) do
        if client.initialized then
          local cap = Util.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Util.matches_filters(cap.filters or {}, old) then
            local edit = Util.get_workspace_edit("willRenameFiles", client, old, new)
            if edit then
              Util.client_apply_workspace_edit(client, mtd, edit)
            end
          end
        end
      end
    end
  end
end

---@param bufnr integer
---@param fname string
---@return boolean success
local function delete_buf(bufnr, fname)
  Util.validate({
    bufnr = { bufnr, { "number" } },
    fname = { fname, { "string" } },
  })

  if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_name(bufnr) ~= fname then
    return true
  end

  Log.debug("Deleting buffer with ID", bufnr)
  return (pcall(vim.api.nvim_buf_delete, bufnr, { force = true }))
end

---@param opts? LspFileOpsConfig
function M.setup(opts)
  M.config.setup(opts)
end

M.did_create = gen_callback("didCreate") --- Wrapper for the `$workspace/didCreateFiles` method
M.did_delete = gen_callback("didDelete")
M.did_rename = gen_callback("didRename")
M.will_create = gen_callback("willCreate")
M.will_delete = gen_callback("willDelete")
M.will_rename = gen_callback("willRename")

---The extra client capabilities provided by this plugin to be merged with
---`vim.lsp.protocol.make_client_capabilities()` and sent to the LSP server.
---
---@see vim.lsp.protocol.make_client_capabilities
---@return lsp.ClientCapabilities capabilities
function M.default_capabilities()
  local config = M.config.get() or M.config.get_defaults()
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
---@param fname string
---@return boolean success
function M.create(fname)
  Util.validate({ fname = { fname, { "string" } } })
  if fname == "" then
    return false
  end
  local is_dir = fname:sub(-1) == "/"
  fname = Util.strip_slash(fname)

  if uv.fs_stat(fname) ~= nil then -- Abort if target already exists
    Log.debug("Target file for `create()` already exists:", fname)
    return false
  end

  M.will_create({ fname = fname })

  local dir = Util.strip_slash(fname, ":h")
  if vim.fn.isdirectory(dir) ~= 1 and mkdir(dir) then
    Log.error("Unable to create parent directories for `create()`:", fname)
    return false
  end

  if is_dir then
    assert(mkdir(fname))
    Log.debug("Created directory:", fname)
  else
    local fd, err = uv.fs_open(fname, "w", tonumber("644", 8))
    if not fd then
      Log.error("Failed to create file for `create()`:", err)
      return false
    end
    Log.debug("Created file:", fname)
    uv.fs_close(fd)
  end

  M.did_create({ fname = fname })
  return (
    pcall(function()
      if not is_dir then
        vim.cmd.edit({ args = { vim.fn.fnameescape(fname) } })
      end
    end)
  )
end

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---@param fname string
---@return boolean success
function M.delete(fname)
  Util.validate({ fname = { fname, { "string" } } })
  if fname == "" then
    Log.error("Target file name for `delete()` is empty")
    return false
  end

  fname = Util.strip_slash(fname)
  local stat = uv.fs_stat(fname)
  if not stat then
    Log.error("Target file name for `delete()` does not exist")
    return false
  end

  M.will_delete({ fname = fname })

  local rm_ok, rm_err = (stat.type == "directory" and uv.fs_rmdir or uv.fs_unlink)(fname)
  if not rm_ok then
    Log.error("Failed to delete file for `delete()`:", rm_err)
    return false
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if not delete_buf(bufnr, fname) then
      Log.warn("Unable to delete buffer ID", bufnr)
    end
  end

  M.did_delete({ fname = fname })
  return true
end

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---@overload fun(new_name: string): success: boolean
---@overload fun(new_name: string, old_name: string): success: boolean
function M.rename(new_name, old_name)
  Util.validate({
    new_name = { new_name, { "string" } },
    old_name = { old_name, { "string", "nil" }, true },
  })
  old_name = old_name or vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  if vim.list_contains({ new_name, old_name }, "") then
    Log.error("Either `new_name` or `old_name` for `rename()` are empty")
    return false
  end
  old_name, new_name = Util.strip_slash(old_name), Util.strip_slash(new_name)

  M.will_rename({ new_name = new_name, old_name = old_name })

  local dir = Util.strip_slash(new_name, ":h")
  if vim.fn.isdirectory(dir) ~= 1 then
    assert(mkdir(dir), ("Unable to create parent directory for target: `%s`"):format(dir))
  end

  local rename_ok, rename_err = uv.fs_rename(old_name, new_name)
  if not rename_ok then
    Log.error("Failed to rename for `rename()`:", rename_err)
    return false
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    rename_buf(bufnr, old_name, new_name)
  end

  M.did_rename({ new_name = new_name, old_name = old_name })
  return true
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
