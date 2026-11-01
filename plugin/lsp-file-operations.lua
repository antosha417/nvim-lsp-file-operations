if vim.g.loaded_lsp_file_operations == 1 then
  return
end
vim.g.loaded_lsp_file_operations = 1

local LFO = require("lsp-file-operations")

---@param line string
---@return string[] items
local function completor(_, line)
  local args = LFO.util.dedup(vim.split(line, " ", { trimempty = false }))
  local items = {} ---@type string[]
  if args[1]:sub(-1) == "!" then -- Don't trigger completions if user command is called with a "bang"
    items = {}
  elseif #args == 2 then -- Complete the second word
    for _, item in ipairs({ "create", "delete", "rename" }) do
      if vim.startswith(item, args[#args]) then
        table.insert(items, item)
      end
    end
  elseif
    (args[2] == "rename" and #args >= 3 and #args <= 4)
    or (vim.list_contains({ "create", "delete" }, args[2]) and #args == 3)
  then
    items = vim.fn.getcompletion(args[#args], "file")
  end
  return items
end

---@param subcommand string
---@param msg string
local function command_error(subcommand, msg)
  LFO.util.validate({
    subcommand = { subcommand, { "string" } },
    msg = { msg, { "string" } },
  })

  LFO.log.notify_error(("`:LFO %s` %s"):format(subcommand, msg))
end

vim.api.nvim_create_user_command("LFO", function(ctx)
  if not vim.list_contains({ "create", "delete", "rename" }, ctx.fargs[1]) then
    LFO.log.notify_error(("Unknown argument for `:LFO` - `%s`"):format(ctx.fargs[1]))
  elseif vim.list_contains({ "create", "delete" }, ctx.fargs[1]) and #ctx.fargs < 2 then
    command_error(ctx.fargs[1], "requires one argument")
  elseif vim.list_contains({ "create", "delete" }, ctx.fargs[1]) and #ctx.fargs > 2 then
    command_error(ctx.fargs[1], "only accepts one argument")
  elseif ctx.fargs[1] == "rename" and #ctx.fargs < 2 or #ctx.fargs > 3 then
    command_error(ctx.fargs[1], "only accepts either one or two arguments")
  elseif vim.list_contains({ "create", "delete" }, ctx.fargs[1]) and #ctx.fargs == 2 then
    (ctx.fargs[1] == "create" and LFO.create or LFO.delete)(ctx.fargs[2])
  elseif ctx.fargs[1] == "rename" and #ctx.fargs <= 3 then
    LFO.rename(ctx.fargs[#ctx.fargs == 3 and 3 or 2], #ctx.fargs == 3 and ctx.fargs[2] or nil)
  end
end, { complete = completor, nargs = "+" })
