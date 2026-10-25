---@module "lsp-file-operations._meta"

local uv = vim.uv or vim.loop

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  local Util = require("lsp-file-operations.util")
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

---@class LFO
---@field ["did-create"] fun(data: { fname: string })
---@field ["did-delete"] fun(data: { fname: string })
---@field ["did-rename"] fun(data: { new_name: string, old_name: string })
---@field ["will-create"] fun(data: { fname: string })
---@field ["will-delete"] fun(data: { fname: string })
---@field ["will-rename"] fun(data: { new_name: string, old_name: string })
---@field config LFO.Config
---@field didCreate fun(data: { fname: string })
---@field didDelete fun(data: { fname: string })
---@field didRename fun(data: { new_name: string, old_name: string })
---@field did_create fun(data: { fname: string })
---@field did_delete fun(data: { fname: string })
---@field did_rename fun(data: { new_name: string, old_name: string })
---@field get_config fun(): config: LFOConfig
---@field log LFO.Log
---@field set_config (fun())|(fun(cfg: LFOConfig))
---@field setup (fun())|(fun(opts: LFOConfig))
---@field util LFO.Util
---@field willCreate fun(data: { fname: string })
---@field willDelete fun(data: { fname: string })
---@field willRename fun(data: { new_name: string, old_name: string })
---@field will_create fun(data: { fname: string })
---@field will_delete fun(data: { fname: string })
---@field will_rename fun(data: { new_name: string, old_name: string })
local M = {}

---@overload fun(method: "didCreate"|"didDelete"|"willCreate"|"willDelete"): callback: fun(data: { fname: string })
---@overload fun(method: "didRename"|"willRename"): callback: fun(data: { new_name: string, old_name: string })
local function gen_callback(method)
  local Util = require("lsp-file-operations.util")
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
            M.log.debug(("Sending %s notification"):format(mtd), params)
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
            M.log.debug(("Sending %s notification"):format(mtd), params)
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

setmetatable(M, {
  __index = function(self, k) ---@param self LFO
    local raw = require("lsp-file-operations.util").get(self, k)
    if raw ~= nil then
      return raw
    end

    if type(k) ~= "string" then
      return
    end

    ---@cast k string
    local ok_mod, mod = pcall(require, "lsp-file-operations." .. k)
    if ok_mod and mod then
      return get(self, k, mod)
    end
    if k == "get_config" then
      return get(self, k, self.config.get)
    end
    if k == "did_create" then
      return get(self, k, gen_callback("didCreate"))
    end
    if k == "did_delete" then
      return get(self, k, gen_callback("didDelete"))
    end
    if k == "did_rename" then
      return get(self, k, gen_callback("didRename"))
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
    if k == "set_config" then
      return get(self, k, self.config.set)
    end
    if k == "setup" then
      return get(self, k, self.config.setup)
    end
    if k == "will_create" then
      return get(self, k, gen_callback("willCreate"))
    end
    if k == "will_delete" then
      return get(self, k, gen_callback("willDelete"))
    end
    if k == "will_rename" then
      return get(self, k, gen_callback("willRename"))
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
  M.util.validate({
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
        pcall(vim.cmd.write, { mods = { noautocmd = true } })
      end
      vim.cmd.checktime()
    end)
  end
end

---@param bufnr integer
---@param fname string
---@return boolean success
local function delete_buf(bufnr, fname)
  M.util.validate({
    bufnr = { bufnr, { "number" } },
    fname = { fname, { "string" } },
  })

  if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_name(bufnr) ~= fname then
    return true
  end

  M.log.debug("Deleting buffer with ID", bufnr)
  return (pcall(vim.api.nvim_buf_delete, bufnr, { force = true }))
end

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

---@param path string
---@return boolean success
local function mkdir(path)
  M.util.validate({ path = { path, { "string" } } })

  local result ---@type boolean
  if vim.fn.has("nvim-0.13") == 1 then
    M.log.debug("Neovim version >=v0.13.0, using `vim.fs.mkdir()`")
    result = (pcall(vim.fs.mkdir, path, { parents = true }))
  else
    M.log.debug("Neovim version <v0.13.0, using `vim.fn.mkdir()`")
    result = vim.fn.mkdir(path, "p") == 1
  end
  return result
end

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---
---@param fname string
---@param opts { dir?: boolean, overwrite?: boolean }
---@return boolean success
---@overload fun(fname: string): success: boolean
function M.create(fname, opts)
  M.util.validate({
    fname = { fname, { "string" } },
    opts = { opts, { "table", "nil" }, true },
  })
  opts = opts or {}
  M.util.validate({
    ["opts.dir"] = { opts.dir, { "boolean", "nil" }, true },
    ["opts.overwrite"] = { opts.overwrite, { "boolean", "nil" }, true },
  })
  if opts.dir == nil then
    opts.dir = false
  end
  if opts.overwrite == nil then
    opts.overwrite = false
  end

  if fname == "" then
    return false
  end

  if fname:sub(-1) == "/" then
    opts.dir = true
  end

  fname = M.util.strip_slash(fname)

  if uv.fs_stat(fname) ~= nil and not opts.overwrite then
    M.log.debug("Target file for `create()` already exists:", fname)
    return false
  end

  M.will_create({ fname = fname })

  local dir = M.util.strip_slash(fname, ":h")
  if vim.fn.isdirectory(dir) ~= 1 and not mkdir(dir) then
    M.log.notify_error("Unable to create parent directories for `create()`:", fname)
    return false
  end

  if opts.dir then
    assert(mkdir(fname))
    M.log.debug("Created directory:", fname)
  else
    local fd, err = uv.fs_open(fname, "w", tonumber("644", 8))
    assert(fd ~= nil, ("Failed to create file: %s"):format(tostring(err)))

    if opts.overwrite then
      assert(uv.fs_write(fd, ""), ("Unable to overwrite `%s`"):format(fname))
    end

    M.log.debug("Created file:", fname)
    assert(uv.fs_close(fd), ("Unable to close file descriptor for `%s`"):format(fname))
  end

  M.did_create({ fname = fname })
  return (
    pcall(function()
      if not opts.dir then
        vim.cmd.edit({ args = { vim.fn.fnameescape(fname) } })
      end
    end)
  )
end

---Sourced from `Crysthamus/nvim-file-operations`:
---https://github.com/Crysthamus/nvim-file-operations/blob/main/lua/nvim-file-operations.lua
---
---@param fname string
---@return boolean success
function M.delete(fname)
  M.util.validate({ fname = { fname, { "string" } } })
  if fname == "" then
    M.log.notify_error("Target file name for `delete()` is empty")
    return false
  end

  fname = M.util.strip_slash(fname)
  local stat = uv.fs_stat(fname)
  if not stat then
    M.log.notify_error("Target file name for `delete()` does not exist")
    return false
  end

  M.will_delete({ fname = fname })

  assert(
    (stat.type == "directory" and uv.fs_rmdir or uv.fs_unlink)(fname),
    ("Unable to delete target file/directory: `%s`"):format(fname)
  )

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if not delete_buf(bufnr, fname) then
      M.log.notify_warn("Unable to delete buffer ID", bufnr)
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
  M.util.validate({
    new_name = { new_name, { "string" } },
    old_name = { old_name, { "string", "nil" }, true },
  })
  old_name = old_name or vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  if vim.list_contains({ new_name, old_name }, "") then
    M.log.notify_error("Either `new_name` or `old_name` for `rename()` are empty")
    return false
  end

  old_name, new_name = M.util.strip_slash(old_name), M.util.strip_slash(new_name)

  M.will_rename({ new_name = new_name, old_name = old_name })

  local dir = M.util.strip_slash(new_name, ":h")
  if vim.fn.isdirectory(dir) ~= 1 and not mkdir(dir) then
    M.log.notify_error("Unable to create parent directory for target", dir)
    return false
  end

  local rename_ok, rename_err = uv.fs_rename(old_name, new_name)
  if not rename_ok then
    M.log.notify_error("Failed to rename target file:", rename_err)
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
