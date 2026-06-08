local wk = require("which-key")

wk.setup {
  preset = "modern",
  icons = {
    mappings = false,
  },
}

wk.add {
  { "<leader>b", group = "buffer" },
  { "<leader>c", group = "code/config" },
  { "<leader>d", group = "diagnostics" },
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>h", group = "git hunk" },
  { "<leader>l", group = "lsp" },
  { "<leader>lg", group = "glance" },
  { "<leader>lw", group = "workspace" },
  { "<leader>s", group = "system" },
}
