---@module "lsp-file-operations._meta"

---@class LspFileOps.Utils
local M = {}

---Get rid of all duplicates in input table.
---
---If table is empty, it'll just return it as-is.
---
---If the data passed to the function is not a table,
---an error will be raised.
--- ---
---@generic T: table
---@param T T
---@param key? string|integer
---@return T NT
---@nodiscard
function M.dedup(T, key)
  M.validate({
    T = { T, { "table" } },
    key = { key, { "string", "nil" }, true },
  })
  key = (key and key ~= "") and key or nil
  if vim.tbl_isempty(T) then
    return T
  end

  local names, NT = {}, {}
  for k, v in pairs(T) do
    local not_dup = false
    if (type(v) == "table" and not key) or type(v) ~= "table" then
      not_dup = not vim.tbl_contains(NT, function(val)
        return vim.deep_equal(val, v)
      end, { predicate = true })
    elseif type(v) == "table" and key then
      not_dup = not vim.tbl_contains(names, function(val)
        return vim.deep_equal(val, v[key])
      end, { predicate = true })
      if not_dup then
        table.insert(names, v[key])
      end
    end
    if not_dup and vim.islist(T) then
      table.insert(NT, v)
    elseif not_dup then
      NT[k] = v
    end
  end
  return NT
end

---Dynamic `vim.validate()` wrapper. Covers both legacy and newer implementations.
--- ---
---@param T table<string, vim.validate.Spec|LspFileOps.ValidateSpec>
function M.validate(T)
  -- Both APIs accept at most 3 spec elements: value, validator, optional/msg.
  -- On >=0.11 the call is positional: vim.validate(name, value, validator, optional).
  for name, spec in pairs(T) do
    while #spec > 3 do
      table.remove(spec, #spec)
    end
    T[name] = spec
  end

  if vim.fn.has("nvim-0.11") == 1 then
    ---@cast T LspFileOps.ValidateSpec
    for name, spec in pairs(T) do
      table.insert(spec, 1, name)
      vim.validate(unpack(spec))
    end
  else
    ---@cast T vim.validate.Spec
    vim.validate(T)
  end
end

---@return vim.lsp.Client[] clients
function M.get_clients()
  ---@diagnostic disable-next-line:deprecated
  return vim.fn.has("nvim-0.10") == 1 and vim.lsp.get_clients() or vim.lsp.get_active_clients()
end

---@param client vim.lsp.Client
---@param method vim.lsp.protocol.Method
---@param params? table
function M.client_notify(client, method, params)
  M.validate({
    client = { client, { "table" } },
    method = { method, { "string" } },
    params = { params, { "table", "nil" }, true },
  })

  pcall(function()
    local args = { client, method, params }
    return client.notify(unpack(args, vim.fn.has("nvim-0.11") == 1 and 1 or 2, #args))
  end)
end

---@param T table
---@param keys string[]
---@return lsp.FileOperationRegistrationOptions|nil|? nested_path
function M.get_nested_path(T, keys)
  if vim.tbl_isempty(keys) then
    return T
  end

  M.validate({
    T = { T, { "table" } },
    keys = { keys, { "table" } },
  })

  return vim.tbl_isempty(keys) and T
    or (T[keys[1]] ~= nil and M.get_nested_path(T[keys[1]], { unpack(keys, 2) }) or nil)
end

-- needed for globs like `**/`
---@param path string
---@param is_dir boolean
---@return string path
local function ensure_dir_trailing_slash(path, is_dir)
  M.validate({
    path = { path, { "string" } },
    is_dir = { is_dir, { "boolean" } },
  })

  return path .. ((is_dir and not path:match("/$")) and "/" or "")
end

---@param name string
---@return string absolute_path
---@return boolean is_dir
local function get_absolute_path(name)
  M.validate({ name = { name, { "string" } } })

  local is_dir = vim.fn.isdirectory(name) == 1
  return ensure_dir_trailing_slash(vim.fn.fnamemodify(name, ":p"), is_dir), is_dir
end

---@param pattern lsp.FileOperationPattern
---@return string regex
local function get_regex(pattern)
  M.validate({ pattern = { pattern, { "table" } } })

  return ((pattern.options and pattern.options.ignoreCase) and [[\c]] or "")
    .. vim.fn.glob2regpat(pattern.glob)
end

-- filter: FileOperationFilter
---@param filter lsp.FileOperationFilter
---@param name string
---@param is_dir boolean
---@return boolean matched
local function match_filter(filter, name, is_dir)
  M.validate({
    filter = { filter, { "table" } },
    name = { name, { "string" } },
    is_dir = { is_dir, { "boolean" } },
  })

  local matched = false
  if
    not filter.pattern.matches
    or (filter.pattern.matches == "folder" and is_dir)
    or (filter.pattern.matches == "file" and not is_dir)
  then
    local regex = get_regex(filter.pattern)
    require("lsp-file-operations.log").debug("Matching name", name, "to pattern", regex)

    local previous_ignorecase = vim.o.ignorecase
    vim.o.ignorecase = false

    matched = vim.fn.match(name, regex) ~= -1
    vim.o.ignorecase = previous_ignorecase
  end
  return matched
end

---@param filters lsp.FileOperationFilter[]
---@param name string
---@return boolean matches
function M.matches_filters(filters, name)
  M.validate({
    filters = { filters, { "table" } },
    name = { name, { "string" } },
  })

  local log = require("lsp-file-operations.log")
  local absolute_path, is_dir = get_absolute_path(name)
  for _, filter in pairs(filters) do
    if match_filter(filter, absolute_path, is_dir) then
      log.debug("Path did match the filter", absolute_path, filter)
      return true
    end
  end
  log.debug("Path didn't match any filters", absolute_path, filters)
  return false
end

---@return lsp.WorkspaceEdit|nil|? workspace_edit
---@overload fun(request: "willCreateFiles"|"willDeleteFiles", client: vim.lsp.Client, fname: string): workspace_edit: lsp.WorkspaceEdit|nil|?
---@overload fun(request: "willRenameFiles", client: vim.lsp.Client, old_name: string, new_name: string): workspace_edit: lsp.WorkspaceEdit|nil|?
function M.get_workspace_edit(request, client, fname_or_old_name, new_name)
  M.validate({
    request = { request, { "string" } },
    client = { client, { "table" } },
    fname_or_old_name = { fname_or_old_name, { "string" } },
    new_name = { new_name, { "string", "nil" }, true },
  })

  if
    not vim.tbl_contains({ "willCreateFiles", "willDeleteFiles", "willRenameFiles" }, request)
    or (request == "willRenameFiles" and not new_name)
  then -- Abort on invalid/incomplete parameters
    return
  end

  local log = require("lsp-file-operations.log")
  local params = {
    files = {
      request == "willRenameFiles" and {
        newUri = vim.uri_from_fname(new_name),
        oldUri = vim.uri_from_fname(fname_or_old_name),
      } or { uri = vim.uri_from_fname(fname_or_old_name) },
    },
  }
  local method = ("workspace/%s"):format(request)
  log.debug(("Sending %s request"):format(method), params)

  ---@type boolean, { err?: lsp.ResponseError, result?: lsp.WorkspaceEdit }|nil|?
  local success, resp = pcall(function()
    local args = { client, method, params, require("lsp-file-operations").get_config().timeout_ms }
    return client.request_sync(unpack(args, vim.fn.has("nvim-0.11") == 1 and 1 or 2, #args))
  end)
  if success and resp and resp.result then
    log.debug(("Got %s response"):format(method), resp)
    return resp.result
  end

  if not success then
    log.error(("Error while sending (%s) request"):format(method), resp)
  elseif not (resp and resp.result) then
    log.warn(("Got empty %s response, maybe a timeout?"):format(method))
  end
end

return M
