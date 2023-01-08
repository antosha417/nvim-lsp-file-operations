local Path = require("plenary").Path
local globtopattern = require("globtopattern").globtopattern

local log = require("lsp-file-operations.log")

local M = {}

M.get_nested_path = function(table, keys)
  if #keys == 0 then
    return table
  end
  local key = keys[1]
  if table[key] == nil then
    return nil
  end
  return M.get_nested_path(table[key], { unpack(keys, 2) })
end

-- needed for globs like `**/`
local ensure_dir_trailing_slash = function(path, is_dir)
  if is_dir and not path:match("/$") then
    return path .. '/'
  end
  return path
end

local get_absolute_path = function(name)
  local path = Path:new(name)
  local is_dir = path:is_dir()
  local absolute_path = ensure_dir_trailing_slash(path:absolute(), is_dir)
  return absolute_path, is_dir
end

-- filter: FileOperationFilter
local match_filter = function(filter, name, is_dir)
  -- TODO what is filter.scheme?
  -- TODO should also match pattern.options?
  local pattern = filter.pattern
  local match_type = pattern.matches
  if not match_type or
      (match_type == "folder" and is_dir) or
      (match_type == "file" and not is_dir)
  then
    local regex = globtopattern(pattern.glob)
    log.debug("Matching name", name, "to pattern", regex)
    return name:match(regex)
  end

  return false
end

-- filters: FileOperationFilter[]
M.matches_filters = function(filters, name)
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
