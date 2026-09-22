-- minimal init for running tests headlessly
-- plenary.nvim is expected at .test-deps/plenary.nvim
vim.opt.rtp:prepend(".test-deps/plenary.nvim")
vim.opt.rtp:prepend(".")
vim.cmd("runtime! plugin/plenary.vim")
