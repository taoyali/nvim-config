local utils = require("utils")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_buf_conf", { clear = true }),
  callback = function(event_context)
    local client = vim.lsp.get_client_by_id(event_context.data.client_id)
    -- vim.print(client.name, client.server_capabilities)

    if not client then
      return
    end

    local bufnr = event_context.buf

    -- Mappings.
    local map = function(mode, l, r, opts)
      opts = opts or {}
      opts.silent = true
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    -- Definition, with a fallback for symbols the server cannot locate.
    --
    -- On Android/Gradle projects kotlin-language-server resolves library types
    -- fine (hover shows them) but has no source location to jump to: its Gradle
    -- classpath resolver never populates sourceJar, so every dependency entry is
    -- source-less. Rather than making the user remember a second keymap for
    -- "symbols that live in a jar", `gd` asks the server first and hands over to
    -- dep_source only when the answer comes back empty.
    local function definition_or_dependency_source()
      -- Android resources first. This cannot be a fallback: kotlin-language-server
      -- *does* answer for `R.string.foo` -- it resolves the field in the generated
      -- R.jar -- so a non-empty result would short-circuit the chain and land in a
      -- decompiled R class. res/ is not on any classpath, so no server will ever
      -- offer strings.xml. android_res declines anything that is not a resource
      -- reference, leaving the normal path untouched.
      if require("android_res").goto_definition() then
        return
      end

      local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

      vim.lsp.buf_request_all(bufnr, "textDocument/definition", params, function(results)
        local items = {}

        for client_id, response in pairs(results or {}) do
          local result = response and response.result
          if result then
            -- The spec allows a single Location or an array of them.
            local locations = (result.uri or result.targetUri) and { result } or result
            local c = vim.lsp.get_client_by_id(client_id)
            if c and #locations > 0 then
              vim.list_extend(items, vim.lsp.util.locations_to_items(locations, c.offset_encoding))
            end
          end
        end

        if #items == 0 then
          -- Deferred on purpose: this callback runs in a fast event context,
          -- where buffer creation and blocking vim.system() calls are unsafe.
          vim.schedule(function()
            require("dep_source").goto_dependency_source()
          end)
          return
        end

        -- Collapse duplicates reported for one declaration, e.g. the
        -- `local M.my_fn_name = function() ... end` style in Lua.
        -- See https://www.reddit.com/r/neovim/comments/19cvgtp/any_way_to_remove_redundant_definition_in_lua_file/
        local unique_defs = {}
        local seen = {}
        for _, item in ipairs(items) do
          -- filename + line uniquely identifies a definition; two declarations
          -- never legitimately share one line.
          local hash_key = item.filename .. item.lnum
          if not seen[hash_key] then
            seen[hash_key] = true
            table.insert(unique_defs, item)
          end
        end

        vim.fn.setloclist(0, {}, " ", { title = "LSP definitions", items = unique_defs })

        -- Jump straight there for a single hit; let the user choose otherwise.
        if #unique_defs > 1 then
          vim.cmd.lopen()
        else
          vim.cmd([[silent! lfirst]])
        end
      end)
    end

    map("n", "gd", definition_or_dependency_source, { desc = "go to definition" })
    map("n", "<C-]>", definition_or_dependency_source, { desc = "go to definition" })
    map("n", "K", function()
      vim.lsp.buf.hover {
        border = "single",
        max_height = 20,
        max_width = 130,
        close_events = { "CursorMoved", "BufLeave", "WinLeave", "LSPDetach" },
      }
    end)
    map("n", "<C-k>", vim.lsp.buf.signature_help)
    map("n", "<leader>lr", vim.lsp.buf.rename, { desc = "variable rename" })
    map("n", "<leader>la", vim.lsp.buf.code_action, { desc = "LSP code action" })
    map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
    map(
      "n",
      "<leader>lwr",
      vim.lsp.buf.remove_workspace_folder,
      { desc = "remove workspace folder" }
    )
    map("n", "<leader>lwl", function()
      vim.print(vim.lsp.buf.list_workspace_folders())
    end, { desc = "list workspace folder" })

    -- Set some key bindings conditional on server capabilities
    -- Disable ruff hover feature in favor of Pyright
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
  end,
  nested = true,
  desc = "Configure buffer keymap and behavior based on LSP",
})

-- Enable lsp servers when they are available

local capabilities = require("lsp_utils").get_default_capabilities()

-- `*` will set default config for all lsp
vim.lsp.config("*", {
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 500,
  },
})

local mason_available, mason = pcall(require, "mason")
if mason_available then
  mason.setup()
end

-- A mapping from lsp server name to the executable name
local enabled_lsp_servers = {
  bashls = { exe = "bash-language-server", optional = true },

  -- clangd = { exe = "clangd", optional = true },

  -- to install codebook, run `brew install codebook-lsp`
  -- codebook = { exe = "codebook-lsp", optional = true },

  -- the server can be install via homebrew: brew install golangci-lint-langserver
  -- golangci-lint also needs to be installed: https://github.com/golangci/golangci-lint
  golangci_lint_ls = { exe = "golangci-lint-langserver", optional = true },
  gopls = { exe = "gopls", optional = false },
  -- Kotlin is the primary language in the Android repos this config is used on.
  -- kotlin-language-server is the only server measured to actually resolve
  -- symbols there -- it extracts the classpath by asking Gradle directly instead
  -- of going through a project model AGP does not implement. Rationale and
  -- measurements: after/lsp/kotlin_language_server.lua.
  --
  -- Java has no semantic server here on purpose; both candidates fail on AGP, so
  -- it relies on ctags + treesitter (see tags_conf.lua):
  --   * jdtls -- Eclipse Buildship cannot read the AGP model, so it emits a
  --     .classpath with no source folders and no dependencies, then indexes
  --     nothing.
  --   * kotlin-lsp -- bundles no intellij.android.* plugins, so it never learns
  --     AGP's source roots. Imports cleanly, then resolves nothing cross-file.
  kotlin_language_server = { exe = "kotlin-language-server", optional = false },

  lua_ls = { exe = "lua-language-server", optional = false },

  pyright = { exe = "pyright", optional = false },
  ruff = { exe = "ruff", optional = true },

  sourcekit = { exe = "sourcekit-lsp", optional = true },
  -- vtsls provides TypeScript/JavaScript support for React Native's .js/.jsx/.ts/.tsx files.
  vtsls = { exe = "vtsls", optional = false },
  vimls = { exe = "vim-language-server", optional = true },
  yamlls = { exe = "yaml-language-server", optional = true },
}

for server_name, server_info in pairs(enabled_lsp_servers) do
  if server_info.condition == nil or server_info.condition() then
    if utils.executable(server_info.exe) then
      vim.lsp.enable(server_name)
    else
      -- only warn about missing non-optional LSP to avoid noise
      if not server_info.optional then
        local msg = string.format(
          "Executable '%s' for LSP server '%s' not found! LSP Server will not be enabled",
          server_info.exe,
          server_name
        )
        vim.notify(msg, vim.log.levels.WARN, { title = "Nvim-config" })
      end
    end
  end
end

-- LSP related command

vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", {
  desc = "Show LSP Info",
})

vim.api.nvim_create_user_command("AndroidLspInstall", "MasonInstall kotlin-lsp", {
  desc = "Install the Kotlin/Android LSP server",
})

vim.api.nvim_create_user_command("LspLog", function(_)
  local log_path = vim.lsp.log.get_filename()

  vim.cmd(string.format("edit %s", log_path))
end, {
  desc = "Show LSP log",
})

vim.api.nvim_create_user_command("LspRestart", "lsp restart", {
  desc = "Restart LSP",
})

--- show LSP progress (works on Ghostty)
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(ev)
    local value = ev.data.params.value
    vim.api.nvim_echo({ { value.message or "done" } }, false, {
      id = "lsp." .. ev.data.client_id,
      kind = "progress",
      source = "vim.lsp",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
  end,
})

-- this controls the LSP inlayHints behavior
vim.g.lsp_inlay_hint_enabled = false

local update_inlayhint = function(enable)
  -- Some LSP server supports inlay hint, but disable this feature by default, so you may need to
  -- enable inlay hint in the LSP server config.
  vim.lsp.inlay_hint.enable(enable)
end

vim.api.nvim_create_user_command("LspInlayHints", function(context)
  -- vim.print("context", context)
  if context["args"] == "enable" then
    vim.g.lsp_inlay_hint_enabled = true
  end

  if context["args"] == "disable" then
    vim.g.lsp_inlay_hint_enabled = false
  end

  update_inlayhint(vim.g.lsp_inlay_hint_enabled)
end, {
  bang = false,
  nargs = 1,
  force = true,
  desc = "Toggle LSP inlayHints",
  complete = function()
    return { "enable", "disable" }
  end,
})
