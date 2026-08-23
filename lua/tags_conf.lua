--------------------------------------------------------------------------------
-- Ctags symbol index -- the navigation floor under LSP.
--
-- Why this exists: on an Android/AGP project, Java has no usable semantic
-- server. Eclipse Buildship cannot read the AGP variant model, so jdtls yields
-- an empty .classpath and indexes nothing; kotlin-lsp serves Java with hover
-- and go-to-definition only. A tags file restores project-wide symbol search
-- and `<C-]>` across thousands of Java files for a few seconds of indexing.
--
-- Kotlin is indexed too, purely as a fallback for the window before kotlin-lsp
-- finishes importing Gradle.
--------------------------------------------------------------------------------

-- The trailing `;` walks up from the current file's directory, so tags resolve
-- from anywhere in the tree, not just when cwd happens to be the project root.
vim.opt.tags = { "./tags;", "tags" }

-- Generated sources and caches would triple the index while adding nothing you
-- would ever want to jump to.
local EXCLUDES = {
  "build",
  ".git",
  ".gradle",
  ".gradle-local",
  ".idea",
  ".kotlin",
  "node_modules",
}

local ROOT_MARKERS = { "settings.gradle", "settings.gradle.kts", "gradlew", ".git" }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "ctags" })
end

--- Build the ctags argv. Runs with cwd = root and indexes `.`, so paths land in
--- the tags file relative to it -- which is exactly what 'tagrelative' expects.
local function ctags_cmd()
  local cmd = { "ctags", "-R", "--languages=Java,Kotlin", "-f", "tags" }
  for _, dir in ipairs(EXCLUDES) do
    table.insert(cmd, "--exclude=" .. dir)
  end
  table.insert(cmd, ".")

  return cmd
end

local function generate()
  if vim.fn.executable("ctags") == 0 then
    notify("ctags not found -- install with `brew install universal-ctags`", vim.log.levels.ERROR)
    return
  end

  local root = vim.fs.root(0, ROOT_MARKERS) or vim.fn.getcwd()
  notify("indexing " .. vim.fn.fnamemodify(root, ":~"))

  vim.system(ctags_cmd(), { cwd = root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        notify(
          ("failed (exit %d): %s"):format(result.code, result.stderr or ""),
          vim.log.levels.ERROR
        )
        return
      end

      -- Report the tag count so a silently empty index is impossible to miss.
      local tags_file = root .. "/tags"
      local lines = vim.fn.filereadable(tags_file) == 1 and #vim.fn.readfile(tags_file) or 0
      notify(("indexed %d tags -> %s"):format(lines, vim.fn.fnamemodify(tags_file, ":~")))
    end)
  end)
end

vim.api.nvim_create_user_command("TagsGenerate", generate, {
  desc = "Index Java/Kotlin symbols into a project tags file",
})

vim.keymap.set("n", "<leader>fT", "<cmd>FzfLua tags<cr>", { desc = "Fuzzy search project tags" })
