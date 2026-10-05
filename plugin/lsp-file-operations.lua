if vim.g.loaded_lsp_file_operations == 1 then
  return
end
vim.g.loaded_lsp_file_operations = 1

vim.api.nvim_create_user_command("LFO", function(ctx)
  local LFO = require("lsp-file-operations")
  local Log = require("lsp-file-operations.log")
  if
    vim.list_contains({ "create", "delete" }, ctx.fargs[1])
    and #ctx.fargs == 2
    and ctx.fargs[2] ~= ""
  then
    (ctx.fargs[1] == "create" and LFO.create or LFO.delete)(ctx.fargs[2])
  elseif ctx.fargs[1] == "rename" and #ctx.fargs <= 3 then
    LFO.rename(ctx.fargs[#ctx.fargs == 3 and 3 or 2], #ctx.fargs == 3 and ctx.fargs[2] or nil)
  elseif not vim.list_contains({ "create", "delete", "rename" }, ctx.fargs[1]) then
    Log.error(("Unknown argument for `:LFO` - `%s`"):format(ctx.fargs[1]))
  elseif ctx.fargs[1] == "create" and #ctx.fargs ~= 2 or ctx.fargs[2] == "" then
    Log.error("`:LFO create` only accepts one argument (and must not be empty)")
  elseif ctx.fargs[1] == "delete" and #ctx.fargs ~= 2 or ctx.fargs[2] == "" then
    Log.error("`:LFO delete` only accepts one argument (and must not be empty)")
  elseif ctx.fargs[1] == "rename" and #ctx.fargs < 2 or #ctx.fargs > 3 then
    Log.error("`:LFO rename` only accepts either one or two arguments")
  elseif ctx.fargs[1] == "rename" and #ctx.fargs >= 2 and ctx.fargs[2] == "" then
    Log.error("`:LFO rename` requires its first argument not to be empty")
  elseif ctx.fargs[1] == "rename" and #ctx.fargs == 3 and ctx.fargs[3] == "" then
    Log.error("`:LFO rename` requires its second argument not to be empty")
  end
end, {
  nargs = "+",
  complete = function(_, line) ---@param line string
    local args = require("lsp-file-operations.utils").dedup(vim.split(line, " ", {
      trimempty = false,
    }))
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
      (#args >= 3 and #args <= 4 and args[2] == "rename")
      or (vim.list_contains({ "create", "delete" }, args[2]) and #args == 3)
    then
      items = vim.fn.getcompletion(args[#args], "file")
    end
    return items
  end,
})
