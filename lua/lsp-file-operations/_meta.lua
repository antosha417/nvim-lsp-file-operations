---@meta

---@alias LspFileOps.Operations
---|'didCreateFiles'
---|'didDeleteFiles'
---|'didRenameFiles'
---|'willCreateFiles'
---|'willDeleteFiles'
---|'willRenameFiles'

---@alias LspFileOps.AllModules
---|LspFileOps.DidCreate
---|LspFileOps.DidDelete
---|LspFileOps.DidRename
---|LspFileOps.WillCreate
---|LspFileOps.WillDelete
---|LspFileOps.WillRename

---@class (exact) LspFileOpsConfig.Operations
---@field didCreateFiles? boolean
---@field didDeleteFiles? boolean
---@field didRenameFiles? boolean
---@field willCreateFiles? boolean
---@field willDeleteFiles? boolean
---@field willRenameFiles? boolean

---@class (exact) LspFileOpsEvents: LspFileOpsConfig.Operations
---@field didCreateFiles string[]
---@field didDeleteFiles string[]
---@field didRenameFiles string[]
---@field willCreateFiles string[]
---@field willDeleteFiles string[]
---@field willRenameFiles string[]

---@class (exact) LspFileOpsConfig
---@field auto_save? boolean
---@field debug? boolean
---@field operations? LspFileOpsConfig.Operations
---@field timeout_ms? integer

---Non-legacy validation spec (>=v0.11)
---@class LspFileOps.ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

-- vim: set ts=2 sts=2 sw=2 et ai si sta:
