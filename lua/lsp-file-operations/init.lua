---@module "lsp-file-operations._meta"

local uv = vim.uv or vim.loop
local Log = require("lsp-file-operations.log")
local Util = require("lsp-file-operations.util")

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
        require("lsp-file-operations.config").get().auto_save
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
  if vim.list_contains({ "didCreate", "didDelete" }, method) then
    return function(data) ---@param data { fname: string }
      Util.validate({
        data = { data, { "table" } },
        ["data.fname"] = { data.fname, { "string" } },
      })

      local lsp_method = ("workspace/%sFiles"):format(method)
      for _, client in ipairs(Util.get_clients()) do
        if client.initialized then
          local cap = Util.get_nested_path(
            client,
            { "server_capabilities", "workspace", "fileOperations", method }
          )
          if cap and Util.matches_filters(cap.filters or {}, data.fname) then
            local params = { files = { { uri = vim.uri_from_fname(data.fname) } } }
            Util.client_notify(client, lsp_method, params)
            Log.debug(("Sending %s notification"):format(lsp_method), params)
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
      local lsp_method = ("workspace/%sFiles"):format(method)
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
            Util.client_notify(client, lsp_method, params)
            Log.debug(("Sending %s notification"):format(lsp_method), params)
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
            local edit, mtd =
              Util.get_workspace_edit(("%sFiles"):format(method), client, data.fname)
            if edit and mtd then
              Log.debug(("Applying %s edit"):format(mtd), edit)
              vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
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
            local edit, mtd = Util.get_workspace_edit("willRenameFiles", client, old, new)
            if edit and mtd then
              Log.debug(("Applying %s edit"):format(mtd), edit)
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
  Util.validate({
    bufnr = { bufnr, { "number" } },
    fname = { fname, { "string" } },
  })

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == fname then
    Log.debug("Deleting buffer with ID", bufnr)
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
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
---@field utils LspFileOps.Util
---@field willCreate fun(data: { fname: string })
---@field willDelete fun(data: { fname: string })
---@field willRename fun(data: { new_name: string, old_name: string })
---@field will_create fun(data: { fname: string })
---@field will_delete fun(data: { fname: string })
---@field will_rename fun(data: { new_name: string, old_name: string })
local M = {}

---@param opts? LspFileOpsConfig
function M.setup(opts)
  require("lsp-file-operations.config").setup(opts)
end

M.did_create = gen_callback("didCreate")
M.did_delete = gen_callback("didDelete")
M.did_rename = gen_callback("didRename")
M.will_create = gen_callback("willCreate")
M.will_delete = gen_callback("willDelete")
M.will_rename = gen_callback("willRename")

---The extra client capabilities provided by this plugin. To be merged with
---`vim.lsp.protocol.make_client_capabilities()` and sent to the LSP server.
---@return lsp.ClientCapabilities capabilities
function M.default_capabilities()
  local Config = require("lsp-file-operations.config")
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
  if vim.fn.isdirectory(dir) ~= 1 and vim.fn.mkdir(dir, "p") ~= 1 then
    Log.error("Unable to create parent directories for `create()`:", fname)
    return false
  end

  if is_dir then
    uv.fs_mkdir(fname, tonumber("755", 8))
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
    delete_buf(bufnr, fname)
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
    vim.fn.mkdir(dir, "p")
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

local LFO = setmetatable(M, { ---@type LspFileOps
  __index = function(self, k)
    local raw = rawget(self, k) or nil
    if raw ~= nil then
      return raw
    end

    local ok_mod, mod = pcall(require, "lsp-file-operations." .. k)
    if ok_mod and mod then
      return Util.rawset(self, k, mod)
    end
    if k == "get_config" then
      return Util.rawset(self, k, require("lsp-file-operations.config").get)
    end
    if k == "set_config" then
      return Util.rawset(self, k, require("lsp-file-operations.config").set)
    end
    if k == "didCreate" then
      return Util.rawset(self, k, M.did_create)
    end
    if k == "didDelete" then
      return Util.rawset(self, k, M.did_delete)
    end
    if k == "didRename" then
      return Util.rawset(self, k, M.did_rename)
    end
    if k == "did-create" then
      return Util.rawset(self, k, M.did_create)
    end
    if k == "did-delete" then
      return Util.rawset(self, k, M.did_delete)
    end
    if k == "did-rename" then
      return Util.rawset(self, k, M.did_rename)
    end
    if k == "willCreate" then
      return Util.rawset(self, k, M.will_create)
    end
    if k == "willDelete" then
      return Util.rawset(self, k, M.will_delete)
    end
    if k == "willRename" then
      return Util.rawset(self, k, M.will_rename)
    end
    if k == "will-create" then
      return Util.rawset(self, k, M.will_create)
    end
    if k == "will-delete" then
      return Util.rawset(self, k, M.will_delete)
    end
    if k == "will-rename" then
      return Util.rawset(self, k, M.will_rename)
    end
  end,
})

return LFO
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
