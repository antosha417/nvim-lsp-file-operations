if vim.g.loaded_lsp_file_operations == 1 then
  return
end
vim.g.loaded_lsp_file_operations = 1

vim.api.nvim_create_user_command("LFO", function(ctx)
  if #ctx.fargs <= 1 or not vim.list_contains({ "create", "delete", "rename" }, ctx.fargs[1]) then
    return
  end

  local LFO = require("lsp-file-operations")
  if
    vim.list_contains({ "create", "delete" }, ctx.fargs[1])
    and #ctx.fargs == 2
    and ctx.fargs[2] ~= ""
  then
    (ctx.fargs[1] == "create" and LFO.create or LFO.delete)({ fname = ctx.fargs[2] })
  elseif #ctx.fargs <= 3 then
    LFO.rename({
      new_name = ctx.fargs[#ctx.fargs == 3 and 3 or 2],
      old_name = #ctx.fargs == 3 and ctx.fargs[2] or nil,
    })
  end
end, {
  nargs = "+",
  complete = function(_, line)
    local args = require("lsp-file-operations.utils").dedup(vim.split(line, " ", {
      trimempty = false,
    }))
    local items = {} ---@type string[]
    if args[1]:sub(-1) ~= "!" then -- Don't trigger completions if user command is called with a "bang"
      if #args == 2 then -- Complete the second word
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
    end
    return items
  end,
})
