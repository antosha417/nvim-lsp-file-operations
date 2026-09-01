---Non-legacy validation spec (>=v0.11)
---@class LspFileOps.ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

local Path = require("plenary").path
local log = require("lsp-file-operations.log")

---@class LspFileOps.Utils
local M = {}

---Dynamic `vim.validate()` wrapper. Covers both legacy and newer implementations.
--- ---
---@param T table<string, vim.validate.Spec|LspFileOps.ValidateSpec>
function M.validate(T)
  local max = vim.fn.has("nvim-0.11") == 1 and 3 or 4
  for name, spec in pairs(T) do
    while #spec > max do
      table.remove(spec, #spec)
    end
    T[name] = spec
  end

  if max == 3 then
    ---@cast T LspFileOps.ValidateSpec
    for name, spec in pairs(T) do
      table.insert(spec, 1, name)
      vim.validate(unpack(spec))
    end
    return
  end

  ---@cast T vim.validate.Spec
  vim.validate(T)
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

  if vim.fn.has("nvim-0.11") == 1 then
    client:notify(method, params)
    return
  end

  client.notify(method, params) ---@diagnostic disable-line:param-type-mismatch
end

---@param T table
---@param keys (string|integer)[]
---@return table|nil
function M.get_nested_path(T, keys)
  M.validate({
    T = { T, { "table" } },
    keys = { keys, { "table" } },
  })

  if vim.tbl_isempty(keys) then
    return T
  end

  local key = keys[1]
  if T[key] == nil then
    return
  end
  return M.get_nested_path(T[key], { unpack(keys, 2) })
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

  return (is_dir and not path:match("/$")) and (path .. "/") or path
end

---@param name string
---@return string absolute_path
---@return boolean is_dir
local function get_absolute_path(name)
  M.validate({ name = { name, { "string" } } })

  local path = Path:new(name)
  local is_dir = path:is_dir()
  local absolute_path = ensure_dir_trailing_slash(path:absolute(), is_dir)
  return absolute_path, is_dir
end

---@param pattern lsp.FileOperationPattern
---@return string regex
local function get_regex(pattern)
  M.validate({ pattern = { pattern, { "table" } } })

  local regex = vim.fn.glob2regpat(pattern.glob)
  return (pattern.options and pattern.options.ignoreCase) and ("\\c" .. regex) or regex
end

-- filter: FileOperationFilter
---@param filter lsp.FileOperationFilter
---@param name string
---@param is_dir boolean
local function match_filter(filter, name, is_dir)
  M.validate({
    filter = { filter, { "table" } },
    name = { name, { "string" } },
    is_dir = { is_dir, { "boolean" } },
  })

  local match_type = filter.pattern.matches
  if
    not match_type
    or (match_type == "folder" and is_dir)
    or (match_type == "file" and not is_dir)
  then
    local regex = get_regex(filter.pattern)
    log.debug("Matching name", name, "to pattern", regex)
    local previous_ignorecase = vim.o.ignorecase
    vim.o.ignorecase = false
    local matched = vim.fn.match(name, regex) ~= -1
    vim.o.ignorecase = previous_ignorecase
    return matched
  end

  return false
end

-- filters: FileOperationFilter[]
---@param filters lsp.FileOperationFilter[]
---@param name string
function M.matches_filters(filters, name)
  M.validate({
    filters = { filters, { "table" } },
    name = { name, { "string" } },
  })

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

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
