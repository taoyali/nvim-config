-- a list of filetypes to install treesitter parsers and queries
local nvim_treesitter = require("nvim-treesitter")

--------------------------------------------------------------------------------
-- Make treesitter queries reachable, and only if they match the parsers.
--
-- nvim-treesitter (main) keeps queries in `runtime/queries` and puts that on the
-- runtimepath from setup() -- which this config never calls, and lazy only adds
-- the plugin root one level above. So nothing under queries/ was reachable:
-- languages Neovim ships queries for (lua, c, vim, markdown) looked fine, while
-- kotlin and java fell back to whatever a colorscheme's after/queries/ defined --
-- a few captures rather than a grammar, which reads as nearly plain text wherever
-- LSP semantic tokens are not also painting the buffer.
--
-- Version match is not optional here. The installed kotlin parser was compiled
-- 2025-05, the plugin's current query expects a node type (`..<`) that only newer
-- grammars emit. Loading the mismatched pair throws inside the highlighter *from
-- the FileType handler*, which aborts the rest of that event -- taking unrelated
-- FileType autocmds down with it. So each candidate is verified after mounting
-- and unmounted again if its queries do not load.
--
-- Never mount a directory containing lua/: stdpath("data")/site/lazy/nvim-treesitter
-- is a stale master-branch checkout of the entire plugin, and adding it loads its
-- code beside the current version, breaking on APIs main removed.
--------------------------------------------------------------------------------
local function mount_queries(dir)
  -- Never mount a tree that carries plugin code (see the stale checkout above).
  if not vim.uv.fs_stat(dir .. "/queries") or vim.uv.fs_stat(dir .. "/lua") then
    return false
  end

  -- Verify before exposing, not after: parse the candidate's own file against the
  -- installed parser. kotlin is the probe because Neovim ships no query for it,
  -- so the result reflects this directory and nothing else.
  local probe = dir .. "/queries/kotlin/highlights.scm"
  if vim.uv.fs_stat(probe) then
    local src = table.concat(vim.fn.readfile(probe), "\n")
    if not pcall(vim.treesitter.query.parse, "kotlin", src) then
      return false
    end
  end

  vim.opt.runtimepath:append(dir)
  return true
end

for _, dir in ipairs {
  -- Queries contemporary with the installed parsers, exposed without the stale
  -- plugin code that sits beside them.
  vim.fn.stdpath("data") .. "/ts-queries-compat",
  -- Current plugin queries: correct once the parsers are rebuilt.
  vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/runtime",
} do
  if mount_queries(dir) then
    break
  end
end

local ensure_installed = {
  "cpp",
  "diff",
  "go",
  "gomod",
  "gosum",
  "java",
  "javascript",
  "json",
  "kotlin",
  "lua",
  "markdown",
  "python",
  "sh",
  "swift",
  "toml",
  "typescript",
  "vim",
  "xml",
  "yaml",
  "zsh",
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = ensure_installed,

  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local lang = vim.treesitter.language.get_lang(ft)
    if lang == nil then
      return
    end

    -- check if parser is available
    local is_parser_available = vim.treesitter.language.add(lang)
    if not is_parser_available then
      local available_langs = vim.g.ts_available or nvim_treesitter.get_available()
      if not vim.g.ts_available then
        vim.g.ts_available = available_langs
      end

      if vim.tbl_contains(available_langs, lang) then
        -- install treesitter parsers and queries
        local install_msg = string.format("Installing parsers and queries for %s", lang)
        vim.print(install_msg)
        require("nvim-treesitter").install(lang)
      end
    end

    if vim.treesitter.language.add(lang) then
      -- start treesitter highlighting
      vim.treesitter.start(args.buf, lang)

      -- the following two statements will enable treesitter folding
      -- vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      -- vim.wo[0][0].foldmethod = "expr"

      -- enable treesitter-based indentation
      -- vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
