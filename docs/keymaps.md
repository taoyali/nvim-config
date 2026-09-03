# Neovim Keymaps

Runtime snapshot generated: 2026-06-06 12:21:55 +0800
LSP quick reference updated: 2026-08-28
Config root: `/Users/taoyali/.config/nvim`
Leader: `<Space>`

This file combines runtime mappings from Neovim with a static source scan. Runtime mappings show what is loaded during headless startup. The source scan catches lazy-loaded, filetype-local, and autocmd-created mappings that may not exist until the related plugin, buffer, or LSP client is active.

## LSP Keymap Quick Reference

`<leader>` is `<Space>`. The mappings in `lua/lsp_conf.lua` are buffer-local and
are installed when an LSP client attaches. They therefore may not appear in the
global runtime table until an LSP-backed buffer is open.

Main sources: [`lua/lsp_conf.lua`](../lua/lsp_conf.lua),
[`lua/config/glance.lua`](../lua/config/glance.lua),
[`lua/diagnostic-conf.lua`](../lua/diagnostic-conf.lua),
[`lua/dep_source.lua`](../lua/dep_source.lua), and
[`lua/android_res.lua`](../lua/android_res.lua).

### Configured on `LspAttach`

| Mode | Key | Action | Scope / notes |
| --- | --- | --- | --- |
| Normal | `gd` | Go to definition | Buffer-local. Android resources are resolved first; then LSP definitions are used; if none are returned, dependency-source lookup is used. Multiple LSP definitions open the location list. |
| Normal | `<C-]>` | Go to definition | Same LSP/resource/dependency fallback chain as `gd`. |
| Normal | `K` | Show hover documentation | Buffer-local. Uses a single border, max height 20, max width 130, and closes on cursor/buffer/window movement or LSP detach. Ruff hover is disabled so Pyright supplies Python hover. |
| Normal | `<C-k>` | Show signature help | Buffer-local. |
| Normal | `<leader>lr` | Rename symbol | `vim.lsp.buf.rename()`. |
| Normal | `<leader>la` | Code action | `vim.lsp.buf.code_action()`. |
| Normal | `<leader>lwa` | Add workspace folder | `vim.lsp.buf.add_workspace_folder()`. |
| Normal | `<leader>lwr` | Remove workspace folder | `vim.lsp.buf.remove_workspace_folder()`. |
| Normal | `<leader>lwl` | List workspace folders | Prints the folders returned by the active LSP client. |

### LSP navigation and diagnostics helpers

| Mode | Key | Action | Scope / notes |
| --- | --- | --- | --- |
| Normal | `<leader>lgd` | Glance definitions | Global mapping from `lua/config/glance.lua`; opens definitions in Glance. |
| Normal | `<leader>lgr` | Glance references | Global mapping from `lua/config/glance.lua`. |
| Normal | `<leader>lgi` | Glance implementations | Global mapping from `lua/config/glance.lua`. |
| Normal | `<leader>gd` | Go to dependency source | Global fallback for library symbols that have no usable LSP source location. |
| Normal | `<leader>lt` | List Android resource declarations | Lists all translations/qualifiers for the resource under the cursor. |
| Normal | `<leader>lu` | List Android resource usages | Lists every reference to the resource under the cursor. |
| Normal | `<leader>db` | Put buffer diagnostics in quickfix | Diagnostics helper; uses the current buffer. |
| Normal | `<leader>dw` | Put window diagnostics in quickfix | Diagnostics helper; uses diagnostics from opened files in the current window. |

`<leader>lg` itself belongs to LazyGit (`<cmd>LazyGit<cr>`); Glance uses the
longer `lgd`, `lgr`, and `lgi` mappings. The shared prefix can make the
which-key display look confusing, but the actions are distinct.

`gd` has a few intentional file/buffer-specific variants:

- Kotlin/Java get an early `gd` `FileType` mapping while
  `kotlin-language-server` is starting. It tries Android resources first; if a
  definition-capable LSP client is already available it calls LSP, otherwise it
  tries exact ctags matches and then dependency-source lookup. `LspAttach`
  later replaces it with the LSP-first mapping above.
- XML gets a buffer-local Android-resource `gd` because no LSP attaches to XML.
- Dependency-source buffers bind both `gd` and `<C-]>` to the next dependency
  source jump. These buffers are read-only and do not have an LSP client.

### Neovim 0.12 built-in LSP mappings

These are supplied by Neovim itself, not by this config. They are present
unconditionally, but the underlying operation needs an attached client with
the corresponding capability. The configured `<leader>` mappings above are the
preferred mnemonic alternatives.

| Mode | Key | Action |
| --- | --- | --- |
| Normal | `grn` | Rename symbol |
| Normal, Visual | `gra` | Code action |
| Normal | `grx` | Run code lens |
| Normal | `grr` | Find references |
| Normal | `gri` | Go to implementation |
| Normal | `grt` | Go to type definition |
| Normal | `gO` | List document symbols |
| Insert, Select | `<C-S>` | Show signature help |

### Neovim 0.12 built-in diagnostic mappings

These operate on diagnostics published by LSP clients and other diagnostic
sources. The config also sets the diagnostic float style and automatically
opens a float on `CursorHold` when the cursor is on a diagnostic.

| Mode | Key | Action |
| --- | --- | --- |
| Normal | `[d` / `]d` | Jump to the previous / next diagnostic in the current buffer |
| Normal | `[D` / `]D` | Jump to the first / last diagnostic in the current buffer |
| Normal | `<C-W>d` / `<C-W><C-D>` | Show the diagnostic under the cursor |

### LSP-related commands

| Command | Action |
| --- | --- |
| `:DepSource` | Jump into the dependency source of the symbol under the cursor. |
| `:ResDefinition` | Jump to the Android resource under the cursor. |
| `:ResDeclarations` | List Android resource declarations across qualifiers. |
| `:ResUsages` | List references to the Android resource under the cursor. |
| `:LspInfo` | Run `checkhealth vim.lsp`. |
| `:LspLog` | Open the LSP log file. |
| `:LspRestart` | Restart LSP clients. |
| `:AndroidLspInstall` | Install the configured Kotlin/Android LSP package through Mason. |
| `:LspInlayHints enable` | Enable inlay hints (disabled by default). |
| `:LspInlayHints disable` | Disable inlay hints. |

## Runtime Keymaps

### Normal (`n`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>&lt;Space&gt;&lt;Space&gt;</code> | <code>&lt;Cmd&gt;StripTrailingWhitespace&lt;CR&gt;</code> | remove trailing space | noremap |
| <code>&lt;Space&gt;P</code> | <code>m`O&lt;Esc&gt;p``</code> | paste above current line | noremap |
| <code>&lt;Space&gt;Q</code> | <code>&lt;Cmd&gt;qa!&lt;CR&gt;</code> | quit nvim | noremap, silent |
| <code>&lt;Space&gt;bp</code> | <code>&lt;Cmd&gt;BufferLinePick&lt;CR&gt;</code> | pick a buffer | noremap |
| <code>&lt;Space&gt;cb</code> | <code>&lt;Lua callback&gt;</code> | show cursor | noremap |
| <code>&lt;Space&gt;cd</code> | <code>&lt;Cmd&gt;lcd %:p:h&lt;CR&gt;&lt;Cmd&gt;pwd&lt;CR&gt;</code> | change cwd | noremap |
| <code>&lt;Space&gt;cl</code> | <code>&lt;Cmd&gt;call utils#ToggleCursorCol()&lt;CR&gt;</code> | toggle cursor column | noremap |
| <code>&lt;Space&gt;db</code> | <code>&lt;Lua callback&gt;</code> | put buffer diagnostics to qf | noremap |
| <code>&lt;Space&gt;dw</code> | <code>&lt;Lua callback&gt;</code> | put window diagnostics to qf | noremap |
| <code>&lt;Space&gt;e</code> | <code>&lt;Lua callback&gt;</code> | toggle nvim-tree | noremap, expr |
| <code>&lt;Space&gt;j</code> | <code>&lt;Lua callback&gt;</code> | Hop: jump to character pair | noremap |
| <code>&lt;Space&gt;p</code> | <code>m`o&lt;Esc&gt;p``</code> | paste below current line | noremap |
| <code>&lt;Space&gt;q</code> | <code>&lt;Cmd&gt;x&lt;CR&gt;</code> | quit current window | noremap, silent |
| <code>&lt;Space&gt;sv</code> | <code>&lt;Lua callback&gt;</code> | show restart hint | noremap |
| <code>&lt;Space&gt;t</code> | <code>&lt;Cmd&gt;Vista!!&lt;CR&gt;</code> | Toggle tag window | noremap, silent |
| <code>&lt;Space&gt;v</code> | <code>printf('`[%s`]', getregtype()[0])</code> | reselect last pasted area | noremap, expr |
| <code>&lt;Space&gt;w</code> | <code>&lt;Cmd&gt;update&lt;CR&gt;</code> | save buffer | noremap, silent |
| <code>&lt;Space&gt;y</code> | <code>&lt;Cmd&gt;%yank&lt;CR&gt;</code> | yank entire buffer | noremap |
| <code>#</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>&amp;</code> | <code>:&amp;&amp;&lt;CR&gt;</code> | :help &amp;-default | noremap |
| <code>*</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>0</code> | <code>g0</code> |  | noremap |
| <code>;</code> | <code>:</code> |  | noremap |
| <code>&lt;C-L&gt;</code> | <code>&lt;Cmd&gt;nohlsearch&#124;diffupdate&#124;normal! &lt;C-L&gt;&lt;CR&gt;</code> | :help CTRL-L-default | noremap |
| <code>&lt;C-W&gt;&lt;C-D&gt;</code> | <code>&lt;C-W&gt;d</code> | Show diagnostics under the cursor |  |
| <code>&lt;C-W&gt;d</code> | <code>&lt;Lua callback&gt;</code> | Show diagnostics under the cursor | noremap |
| <code>&lt;Down&gt;</code> | <code>&lt;C-W&gt;j</code> |  | noremap |
| <code>&lt;Esc&gt;</code> | <code>&lt;Lua callback&gt;</code> | close floating win | noremap |
| <code>&lt;F11&gt;</code> | <code>&lt;Cmd&gt;set spell!&lt;CR&gt;</code> | toggle spell | noremap |
| <code>&lt;Left&gt;</code> | <code>&lt;C-W&gt;h</code> |  | noremap |
| <code>&lt;M-j&gt;</code> | <code>&lt;Cmd&gt;call utils#SwitchLine(line("."), "down")&lt;CR&gt;</code> | move line down | noremap |
| <code>&lt;M-k&gt;</code> | <code>&lt;Cmd&gt;call utils#SwitchLine(line("."), "up")&lt;CR&gt;</code> | move line up | noremap |
| <code>&lt;Plug&gt;(diffs-conflict-both)</code> | <code>&lt;Lua callback&gt;</code> | Accept both changes | noremap |
| <code>&lt;Plug&gt;(diffs-conflict-next)</code> | <code>&lt;Lua callback&gt;</code> | Jump to next conflict | noremap |
| <code>&lt;Plug&gt;(diffs-conflict-none)</code> | <code>&lt;Lua callback&gt;</code> | Reject both changes | noremap |
| <code>&lt;Plug&gt;(diffs-conflict-ours)</code> | <code>&lt;Lua callback&gt;</code> | Accept current (ours) change | noremap |
| <code>&lt;Plug&gt;(diffs-conflict-prev)</code> | <code>&lt;Lua callback&gt;</code> | Jump to previous conflict | noremap |
| <code>&lt;Plug&gt;(diffs-conflict-theirs)</code> | <code>&lt;Lua callback&gt;</code> | Accept incoming (theirs) change | noremap |
| <code>&lt;Plug&gt;(diffs-gdiff)</code> | <code>&lt;Lua callback&gt;</code> | Unified diff (horizontal) | noremap |
| <code>&lt;Plug&gt;(diffs-gdiff-open-source)</code> | <code>&lt;Lua callback&gt;</code> | Open source file from generated diff | noremap |
| <code>&lt;Plug&gt;(diffs-greview-open-split)</code> | <code>&lt;Lua callback&gt;</code> | Open review file in split diff | noremap |
| <code>&lt;Plug&gt;(diffs-gvdiff)</code> | <code>&lt;Lua callback&gt;</code> | Unified diff (vertical) | noremap |
| <code>&lt;Plug&gt;(diffs-merge-both)</code> | <code>&lt;Lua callback&gt;</code> | Accept both in merge diff | noremap |
| <code>&lt;Plug&gt;(diffs-merge-next)</code> | <code>&lt;Lua callback&gt;</code> | Jump to next conflict hunk | noremap |
| <code>&lt;Plug&gt;(diffs-merge-none)</code> | <code>&lt;Lua callback&gt;</code> | Reject both in merge diff | noremap |
| <code>&lt;Plug&gt;(diffs-merge-ours)</code> | <code>&lt;Lua callback&gt;</code> | Accept ours in merge diff | noremap |
| <code>&lt;Plug&gt;(diffs-merge-prev)</code> | <code>&lt;Lua callback&gt;</code> | Jump to previous conflict hunk | noremap |
| <code>&lt;Plug&gt;(diffs-merge-theirs)</code> | <code>&lt;Lua callback&gt;</code> | Accept theirs in merge diff | noremap |
| <code>&lt;Right&gt;</code> | <code>&lt;C-W&gt;l</code> |  | noremap |
| <code>&lt;Up&gt;</code> | <code>&lt;C-W&gt;k</code> |  | noremap |
| <code>C</code> | <code>"_C</code> |  | noremap |
| <code>H</code> | <code>^</code> |  | noremap |
| <code>J</code> | <code>&lt;Lua callback&gt;</code> | join lines without moving cursor | noremap |
| <code>L</code> | <code>g_</code> |  | noremap |
| <code>N</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>Y</code> | <code>y$</code> | :help Y-default | noremap |
| <code>ZR</code> | <code>&lt;Lua callback&gt;</code> | Restart nvim | noremap, silent |
| <code>[&lt;Space&gt;</code> | <code>&lt;Lua callback&gt;</code> | Add empty line above cursor | noremap, expr |
| <code>[&lt;C-L&gt;</code> | <code>&lt;Lua callback&gt;</code> | :lpfile | noremap |
| <code>[&lt;C-Q&gt;</code> | <code>&lt;Lua callback&gt;</code> | :cpfile | noremap |
| <code>[&lt;C-T&gt;</code> | <code>&lt;Lua callback&gt;</code> | :ptprevious | noremap |
| <code>[A</code> | <code>&lt;Lua callback&gt;</code> | :rewind | noremap |
| <code>[B</code> | <code>&lt;Lua callback&gt;</code> | :brewind | noremap |
| <code>[D</code> | <code>&lt;Lua callback&gt;</code> | Jump to the first diagnostic in the current buffer | noremap |
| <code>[L</code> | <code>&lt;Lua callback&gt;</code> | :lrewind | noremap |
| <code>[Q</code> | <code>&lt;Lua callback&gt;</code> | :crewind | noremap |
| <code>[T</code> | <code>&lt;Lua callback&gt;</code> | :trewind | noremap |
| <code>[a</code> | <code>&lt;Lua callback&gt;</code> | :previous | noremap |
| <code>[b</code> | <code>&lt;Lua callback&gt;</code> | :bprevious | noremap |
| <code>[d</code> | <code>&lt;Lua callback&gt;</code> | Jump to the previous diagnostic in the current buffer | noremap |
| <code>[i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('top', true)&lt;CR&gt;</code> | Go to indent scope top | noremap, silent |
| <code>[l</code> | <code>&lt;Lua callback&gt;</code> | :lprevious | noremap |
| <code>[q</code> | <code>&lt;Lua callback&gt;</code> | :cprevious | noremap |
| <code>[t</code> | <code>&lt;Lua callback&gt;</code> | :tprevious | noremap |
| <code>\dB</code> | <code>&lt;Lua callback&gt;</code> | Delete other buffers | noremap |
| <code>\dT</code> | <code>&lt;Cmd&gt;tabonly&lt;CR&gt;</code> | Delete other tabs | noremap, silent |
| <code>\db</code> | <code>&lt;Cmd&gt;bprevious &#124; bdelete #&lt;CR&gt;</code> | Delete current buffer | noremap, silent |
| <code>\dt</code> | <code>&lt;Cmd&gt;tabclose&lt;CR&gt;</code> | Delete current tab | noremap, silent |
| <code>\x</code> | <code>&lt;Cmd&gt;windo lclose &#124; cclose &lt;CR&gt;</code> | close qf and location list | noremap, silent |
| <code>]&lt;Space&gt;</code> | <code>&lt;Lua callback&gt;</code> | Add empty line below cursor | noremap, expr |
| <code>]&lt;C-L&gt;</code> | <code>&lt;Lua callback&gt;</code> | :lnfile | noremap |
| <code>]&lt;C-Q&gt;</code> | <code>&lt;Lua callback&gt;</code> | :cnfile | noremap |
| <code>]&lt;C-T&gt;</code> | <code>&lt;Lua callback&gt;</code> | :ptnext | noremap |
| <code>]A</code> | <code>&lt;Lua callback&gt;</code> | :last | noremap |
| <code>]B</code> | <code>&lt;Lua callback&gt;</code> | :blast | noremap |
| <code>]D</code> | <code>&lt;Lua callback&gt;</code> | Jump to the last diagnostic in the current buffer | noremap |
| <code>]L</code> | <code>&lt;Lua callback&gt;</code> | :llast | noremap |
| <code>]Q</code> | <code>&lt;Lua callback&gt;</code> | :clast | noremap |
| <code>]T</code> | <code>&lt;Lua callback&gt;</code> | :tlast | noremap |
| <code>]a</code> | <code>&lt;Lua callback&gt;</code> | :next | noremap |
| <code>]b</code> | <code>&lt;Lua callback&gt;</code> | :bnext | noremap |
| <code>]d</code> | <code>&lt;Lua callback&gt;</code> | Jump to the next diagnostic in the current buffer | noremap |
| <code>]i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('bottom', true)&lt;CR&gt;</code> | Go to indent scope bottom | noremap, silent |
| <code>]l</code> | <code>&lt;Lua callback&gt;</code> | :lnext | noremap |
| <code>]q</code> | <code>&lt;Lua callback&gt;</code> | :cnext | noremap |
| <code>]t</code> | <code>&lt;Lua callback&gt;</code> | :tnext | noremap |
| <code>^</code> | <code>g^</code> |  | noremap |
| <code>c</code> | <code>"_c</code> |  | noremap |
| <code>cc</code> | <code>"_cc</code> |  | noremap |
| <code>gB</code> | <code>&lt;Cmd&gt;call buf_utils#GoToBuffer(v:count, "backward")&lt;CR&gt;</code> | go to buffer (backward) | noremap |
| <code>gJ</code> | <code>&lt;Lua callback&gt;</code> | join lines without moving cursor | noremap |
| <code>gO</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.document_symbol() | noremap |
| <code>ga</code> | <code>&lt;Plug&gt;(UnicodeGA)</code> |  |  |
| <code>gb</code> | <code>&lt;Cmd&gt;call buf_utils#GoToBuffer(v:count, "forward")&lt;CR&gt;</code> | go to buffer (forward) | noremap |
| <code>gc</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>gcc</code> | <code>&lt;Lua callback&gt;</code> | Toggle comment line | noremap, expr |
| <code>gra</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.code_action() | noremap |
| <code>gri</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.implementation() | noremap |
| <code>grn</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.rename() | noremap |
| <code>grr</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.references() | noremap |
| <code>grt</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.type_definition() | noremap |
| <code>grx</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.codelens.run() | noremap |
| <code>gx</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>j</code> | <code>v:count == 0 ? 'gj' : 'j'</code> |  | noremap, expr |
| <code>k</code> | <code>v:count == 0 ? 'gk' : 'k'</code> |  | noremap, expr |
| <code>n</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>s</code> | <code></code> |  |  |

### Insert (`i`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>!</code> | <code>!&lt;C-G&gt;u</code> |  | noremap |
| <code>,</code> | <code>,&lt;C-G&gt;u</code> |  | noremap |
| <code>.</code> | <code>.&lt;C-G&gt;u</code> |  | noremap |
| <code>:</code> | <code>:&lt;C-G&gt;u</code> |  | noremap |
| <code>;</code> | <code>;&lt;C-G&gt;u</code> |  | noremap |
| <code>&lt;C-A&gt;</code> | <code>&lt;Home&gt;</code> |  | noremap |
| <code>&lt;C-D&gt;</code> | <code>&lt;Del&gt;</code> |  | noremap |
| <code>&lt;C-E&gt;</code> | <code>&lt;End&gt;</code> |  | noremap |
| <code>&lt;C-S&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.signature_help() | noremap |
| <code>&lt;C-T&gt;</code> | <code>&lt;Esc&gt;b~lea</code> |  | noremap |
| <code>&lt;C-U&gt;</code> | <code>&lt;Esc&gt;viwUea</code> |  | noremap |
| <code>&lt;C-W&gt;</code> | <code>&lt;C-G&gt;u&lt;C-W&gt;</code> | :help i_CTRL-W-default | noremap |
| <code>&lt;F11&gt;</code> | <code>&lt;C-O&gt;&lt;Cmd&gt;set spell!&lt;CR&gt;</code> | toggle spell | noremap |
| <code>&lt;M-;&gt;</code> | <code>&lt;Esc&gt;miA;&lt;Esc&gt;`ii</code> |  | noremap |
| <code>&lt;S-Tab&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.snippet.jump if active, otherwise &lt;S-Tab&gt; | noremap, expr, silent |
| <code>&lt;Tab&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.snippet.jump if active, otherwise &lt;Tab&gt; | noremap, expr, silent |
| <code>?</code> | <code>?&lt;C-G&gt;u</code> |  | noremap |

### Visual+Select (`v`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>#</code> | <code>&lt;Lua callback&gt;</code> | :help v_#-default | noremap, expr |
| <code>$</code> | <code>g_</code> |  | noremap |
| <code>*</code> | <code>&lt;Lua callback&gt;</code> | :help v_star-default | noremap, expr |
| <code>;</code> | <code>:</code> |  | noremap |
| <code>&lt;C-S&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.signature_help() | noremap |
| <code>&lt;M-j&gt;</code> | <code>&lt;Cmd&gt;call utils#MoveSelection("down")&lt;CR&gt;</code> | move selection down | noremap |
| <code>&lt;M-k&gt;</code> | <code>&lt;Cmd&gt;call utils#MoveSelection("up")&lt;CR&gt;</code> | move selection up | noremap |
| <code>&lt;S-Tab&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.snippet.jump if active, otherwise &lt;S-Tab&gt; | noremap, expr, silent |
| <code>&lt;Tab&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.snippet.jump if active, otherwise &lt;Tab&gt; | noremap, expr, silent |
| <code>&lt;lt&gt;</code> | <code>&lt;lt&gt;gv</code> |  | noremap |
| <code>&gt;</code> | <code>&gt;gv</code> |  | noremap |
| <code>@</code> | <code>mode() ==# 'V' ? ':normal! @'.getcharstr().'&lt;CR&gt;' : '@'</code> | :help v_@-default | noremap, expr, silent |
| <code>H</code> | <code>^</code> |  | noremap |
| <code>L</code> | <code>g_</code> |  | noremap |
| <code>Q</code> | <code>mode() ==# 'V' ? ':normal! @&lt;C-R&gt;=reg_recorded()&lt;CR&gt;&lt;CR&gt;' : 'Q'</code> | :help v_Q-default | noremap, expr, silent |
| <code>[i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('top')&lt;CR&gt;</code> | Go to indent scope top | noremap, silent |
| <code>[n</code> | <code>&lt;Lua callback&gt;</code> | Select previous node | noremap |
| <code>]i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('bottom')&lt;CR&gt;</code> | Go to indent scope bottom | noremap, silent |
| <code>]n</code> | <code>&lt;Lua callback&gt;</code> | Select next node | noremap |
| <code>ai</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.textobject(true)&lt;CR&gt;</code> | Object scope with border | noremap, silent |
| <code>an</code> | <code>&lt;Lua callback&gt;</code> | Select parent (outer) node | noremap |
| <code>c</code> | <code>"_c</code> |  | noremap |
| <code>gc</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>gra</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.code_action() | noremap |
| <code>gx</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>iB</code> | <code>:&lt;C-U&gt;call text_obj#Buffer()&lt;CR&gt;</code> | buffer text object | noremap |
| <code>ii</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.textobject(false)&lt;CR&gt;</code> | Object scope | noremap, silent |
| <code>in</code> | <code>&lt;Lua callback&gt;</code> | Select child (inner) node | noremap |
| <code>iu</code> | <code>&lt;Cmd&gt;call text_obj#URL()&lt;CR&gt;</code> | URL text object | noremap |
| <code>p</code> | <code>"_c&lt;Esc&gt;p</code> |  | noremap |

### Visual (`x`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>#</code> | <code>&lt;Lua callback&gt;</code> | :help v_#-default | noremap, expr |
| <code>$</code> | <code>g_</code> |  | noremap |
| <code>*</code> | <code>&lt;Lua callback&gt;</code> | :help v_star-default | noremap, expr |
| <code>;</code> | <code>:</code> |  | noremap |
| <code>&lt;M-j&gt;</code> | <code>&lt;Cmd&gt;call utils#MoveSelection("down")&lt;CR&gt;</code> | move selection down | noremap |
| <code>&lt;M-k&gt;</code> | <code>&lt;Cmd&gt;call utils#MoveSelection("up")&lt;CR&gt;</code> | move selection up | noremap |
| <code>&lt;lt&gt;</code> | <code>&lt;lt&gt;gv</code> |  | noremap |
| <code>&gt;</code> | <code>&gt;gv</code> |  | noremap |
| <code>@</code> | <code>mode() ==# 'V' ? ':normal! @'.getcharstr().'&lt;CR&gt;' : '@'</code> | :help v_@-default | noremap, expr, silent |
| <code>H</code> | <code>^</code> |  | noremap |
| <code>L</code> | <code>g_</code> |  | noremap |
| <code>Q</code> | <code>mode() ==# 'V' ? ':normal! @&lt;C-R&gt;=reg_recorded()&lt;CR&gt;&lt;CR&gt;' : 'Q'</code> | :help v_Q-default | noremap, expr, silent |
| <code>[i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('top')&lt;CR&gt;</code> | Go to indent scope top | noremap, silent |
| <code>[n</code> | <code>&lt;Lua callback&gt;</code> | Select previous node | noremap |
| <code>]i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('bottom')&lt;CR&gt;</code> | Go to indent scope bottom | noremap, silent |
| <code>]n</code> | <code>&lt;Lua callback&gt;</code> | Select next node | noremap |
| <code>ai</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.textobject(true)&lt;CR&gt;</code> | Object scope with border | noremap, silent |
| <code>an</code> | <code>&lt;Lua callback&gt;</code> | Select parent (outer) node | noremap |
| <code>c</code> | <code>"_c</code> |  | noremap |
| <code>gc</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>gra</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.code_action() | noremap |
| <code>gx</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |
| <code>iB</code> | <code>:&lt;C-U&gt;call text_obj#Buffer()&lt;CR&gt;</code> | buffer text object | noremap |
| <code>ii</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.textobject(false)&lt;CR&gt;</code> | Object scope | noremap, silent |
| <code>in</code> | <code>&lt;Lua callback&gt;</code> | Select child (inner) node | noremap |
| <code>iu</code> | <code>&lt;Cmd&gt;call text_obj#URL()&lt;CR&gt;</code> | URL text object | noremap |
| <code>p</code> | <code>"_c&lt;Esc&gt;p</code> |  | noremap |

### Select (`s`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>&lt;C-S&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.lsp.buf.signature_help() | noremap |
| <code>&lt;S-Tab&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.snippet.jump if active, otherwise &lt;S-Tab&gt; | noremap, expr, silent |
| <code>&lt;Tab&gt;</code> | <code>&lt;Lua callback&gt;</code> | vim.snippet.jump if active, otherwise &lt;Tab&gt; | noremap, expr, silent |
| <code>gc</code> | <code>&lt;Lua callback&gt;</code> |  | noremap, expr |

### Operator-pending (`o`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>[i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('top')&lt;CR&gt;</code> | Go to indent scope top | noremap, silent |
| <code>]i</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.operator('bottom')&lt;CR&gt;</code> | Go to indent scope bottom | noremap, silent |
| <code>ai</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.textobject(true)&lt;CR&gt;</code> | Object scope with border | noremap, silent |
| <code>an</code> | <code>&lt;Lua callback&gt;</code> | Select parent (outer) node | noremap |
| <code>gc</code> | <code>&lt;Lua callback&gt;</code> | Comment textobject | noremap |
| <code>iB</code> | <code>:&lt;C-U&gt;call text_obj#Buffer()&lt;CR&gt;</code> | buffer text object | noremap |
| <code>ii</code> | <code>&lt;Cmd&gt;lua MiniIndentscope.textobject(false)&lt;CR&gt;</code> | Object scope | noremap, silent |
| <code>in</code> | <code>&lt;Lua callback&gt;</code> | Select child (inner) node | noremap |
| <code>iu</code> | <code>&lt;Cmd&gt;call text_obj#URL()&lt;CR&gt;</code> | URL text object | noremap |
| <code>s</code> | <code></code> |  |  |

### Command-line (`c`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>&lt;C-A&gt;</code> | <code>&lt;Home&gt;</code> |  | noremap |

### Terminal (`t`)

| LHS | RHS | Description | Options |
| --- | --- | --- | --- |
| <code>&lt;Esc&gt;</code> | <code>&lt;C-\&gt;&lt;C-N&gt;</code> |  | noremap |

## Static Keymap Source Scan

The lines below are direct matches from config files. They include helper functions and commented mappings when those lines contain mapping-related tokens.

```text
ginit.vim:2:inoremap <silent> <S-Insert>  <C-R>+
ginit.vim:3:cnoremap <S-Insert> <C-R>+
ginit.vim:4:nnoremap <silent> <C-6> <C-^>
lua/mappings.lua:5:keymap.set({ "n", "x" }, ";", ":")
lua/mappings.lua:8:keymap.set("i", "<c-u>", "<Esc>viwUea")
lua/mappings.lua:11:keymap.set("i", "<c-t>", "<Esc>b~lea")
lua/mappings.lua:14:keymap.set("n", "<leader>p", "m`o<ESC>p``", { desc = "paste below current line" })
lua/mappings.lua:15:keymap.set("n", "<leader>P", "m`O<ESC>p``", { desc = "paste above current line" })
lua/mappings.lua:18:keymap.set("n", "<leader>w", "<cmd>update<cr>", { silent = true, desc = "save buffer" })
lua/mappings.lua:21:keymap.set("n", "<leader>q", "<cmd>x<cr>", { silent = true, desc = "quit current window" })
lua/mappings.lua:24:keymap.set("n", "<leader>Q", "<cmd>qa!<cr>", { silent = true, desc = "quit nvim" })
lua/mappings.lua:27:keymap.set("n", [[\x]], "<cmd>windo lclose <bar> cclose <cr>", {
lua/mappings.lua:33:keymap.set("n", [[\db]], "<cmd>bprevious <bar> bdelete #<cr>", {
lua/mappings.lua:38:keymap.set("n", [[\dB]], function()
lua/mappings.lua:52:keymap.set("n", [[\dt]], "<cmd>tabclose<CR>", {
lua/mappings.lua:57:keymap.set("n", [[\dT]], "<cmd>tabonly<CR>", {
lua/mappings.lua:63:keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
lua/mappings.lua:64:keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
lua/mappings.lua:65:keymap.set("n", "^", "g^")
lua/mappings.lua:66:keymap.set("n", "0", "g0")
lua/mappings.lua:70:keymap.set("x", "$", "g_")
lua/mappings.lua:73:keymap.set({ "n", "x" }, "H", "^")
lua/mappings.lua:74:keymap.set({ "n", "x" }, "L", "g_")
lua/mappings.lua:78:keymap.set("x", "<", "<gv")
lua/mappings.lua:79:keymap.set("x", ">", ">gv")
lua/mappings.lua:82:keymap.set("n", "<leader>sv", function()
lua/mappings.lua:86:keymap.set("n", "ZR", function()
lua/mappings.lua:96:keymap.set("n", "<leader>v", "printf('`[%s`]', getregtype()[0])", {
lua/mappings.lua:102:-- keymap.set("n", "/", [[/\v]])
lua/mappings.lua:105:-- xnoremap / :<C-U>call feedkeys('/\%>'.(line("'<")-1).'l\%<'.(line("'>")+1)."l")<CR>
lua/mappings.lua:109:keymap.set("n", "<leader>cd", "<cmd>lcd %:p:h<cr><cmd>pwd<cr>", { desc = "change cwd" })
lua/mappings.lua:112:keymap.set("t", "<Esc>", [[<c-\><c-n>]])
lua/mappings.lua:115:keymap.set("n", "<F11>", "<cmd>set spell!<cr>", { desc = "toggle spell" })
lua/mappings.lua:116:keymap.set("i", "<F11>", "<c-o><cmd>set spell!<cr>", { desc = "toggle spell" })
lua/mappings.lua:120:keymap.set("n", "c", '"_c')
lua/mappings.lua:121:keymap.set("n", "C", '"_C')
lua/mappings.lua:122:keymap.set("n", "cc", '"_cc')
lua/mappings.lua:123:keymap.set("x", "c", '"_c')
lua/mappings.lua:126:keymap.set(
lua/mappings.lua:128:  "<leader><space>",
lua/mappings.lua:134:keymap.set("n", "<leader>y", "<cmd>%yank<cr>", { desc = "yank entire buffer" })
lua/mappings.lua:137:keymap.set(
lua/mappings.lua:139:  "<leader>cl",
lua/mappings.lua:145:keymap.set(
lua/mappings.lua:151:keymap.set(
lua/mappings.lua:159:keymap.set("x", "<A-k>", '<cmd>call utils#MoveSelection("up")<cr>', { desc = "move selection up" })
lua/mappings.lua:161:keymap.set(
lua/mappings.lua:170:keymap.set("x", "p", '"_c<Esc>p')
lua/mappings.lua:173:keymap.set("n", "gb", '<cmd>call buf_utils#GoToBuffer(v:count, "forward")<cr>', {
lua/mappings.lua:176:keymap.set("n", "gB", '<cmd>call buf_utils#GoToBuffer(v:count, "backward")<cr>', {
lua/mappings.lua:181:keymap.set("n", "<left>", "<c-w>h")
lua/mappings.lua:182:keymap.set("n", "<Right>", "<C-W>l")
lua/mappings.lua:183:keymap.set("n", "<Up>", "<C-W>k")
lua/mappings.lua:184:keymap.set("n", "<Down>", "<C-W>j")
lua/mappings.lua:187:keymap.set({ "x", "o" }, "iu", "<cmd>call text_obj#URL()<cr>", { desc = "URL text object" })
lua/mappings.lua:190:keymap.set({ "x", "o" }, "iB", ":<C-U>call text_obj#Buffer()<cr>", { desc = "buffer text object" })
lua/mappings.lua:193:keymap.set("n", "J", function()
lua/mappings.lua:202:keymap.set("n", "gJ", function()
lua/mappings.lua:215:  keymap.set("i", ch, ch .. "<c-g>u")
lua/mappings.lua:219:keymap.set("i", "<A-;>", "<Esc>miA;<Esc>`ii")
lua/mappings.lua:222:keymap.set("i", "<C-A>", "<HOME>")
lua/mappings.lua:223:keymap.set("i", "<C-E>", "<END>")
lua/mappings.lua:226:keymap.set("c", "<C-A>", "<HOME>")
lua/mappings.lua:229:keymap.set("i", "<C-D>", "<DEL>")
lua/mappings.lua:231:keymap.set("n", "<leader>cb", function()
lua/mappings.lua:266:keymap.set("n", "<leader>fd", function()
lua/lsp_conf.lua:20:      vim.keymap.set(mode, l, r, opts)
lua/lsp_conf.lua:72:    map("n", "<leader>lr", vim.lsp.buf.rename, { desc = "variable rename" })
lua/lsp_conf.lua:73:    map("n", "<leader>la", vim.lsp.buf.code_action, { desc = "LSP code action" })
lua/lsp_conf.lua:74:    map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
lua/lsp_conf.lua:75:    map("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
lua/lsp_conf.lua:76:    map("n", "<leader>lwl", function()
lua/diagnostic-conf.lua:42:vim.keymap.set("n", "<leader>dw", diagnostic.setqflist, { desc = "put window diagnostics to qf" })
lua/diagnostic-conf.lua:45:vim.keymap.set("n", "<leader>db", function()
lua/globals.lua:31:-- Custom mapping <leader> (see `:h mapleader` for more info)
after/ftplugin/go.lua:11:vim.keymap.set("n", "<leader>cf", function()
after/ftplugin/go.lua:15:vim.keymap.set("n", "<F9>", function()
lua/plugin_specs.lua:350:      vim.keymap.set("n", "<leader>t", "<cmd>Vista!!<CR>", {
lua/plugin_specs.lua:782:      { "<leader>e", desc = "toggle nvim-tree" },
lua/plugin_specs.lua:896:-- short alias, e.g., `pi`, then press <space>, the alias will be expanded to
after/ftplugin/json.lua:1:vim.keymap.set({ "n", "v" }, "<leader>cf", ":JSONFormat<cr>", {
after/ftplugin/vim.vim:15:nnoremap <buffer><silent> <F9> :source %<CR>
after/ftplugin/man.lua:2:vim.keymap.set("n", "q", "<cmd>q<CR>", {
after/ftplugin/lua.lua:4:vim.keymap.set("n", "<F9>", "<cmd>luafile %<CR>", {
after/ftplugin/lua.lua:8:vim.keymap.set("n", "<leader>cf", "<cmd>silent !stylua %<CR>", {
after/ftplugin/markdown.vim:8:  nnoremap <buffer><silent> ^^ :<C-U>call markdownfootnotes#VimFootnotes('i')<CR>
after/ftplugin/markdown.vim:9:  inoremap <buffer><silent> ^^ <C-O>:<C-U>call markdownfootnotes#VimFootnotes('i')<CR>
after/ftplugin/markdown.vim:15:xnoremap <buffer><silent> ic :<C-U>call text_obj#MdCodeBlock('i')<CR>
after/ftplugin/markdown.vim:16:xnoremap <buffer><silent> ac :<C-U>call text_obj#MdCodeBlock('a')<CR>
after/ftplugin/markdown.vim:22:nnoremap <buffer><silent> + :set operatorfunc=AddListSymbol<CR>g@
after/ftplugin/markdown.vim:23:xnoremap <buffer><silent> + :<C-U> call AddListSymbol(visualmode(), 1)<CR>
after/ftplugin/markdown.vim:50:" nnoremap <buffer><silent> \ :set operatorfunc=AddLineBreak<CR>g@
after/ftplugin/markdown.vim:51:xnoremap <buffer><silent> \ :<C-U> call AddLineBreak(visualmode(), 1)<CR>
after/ftplugin/python.lua:58:  vim.keymap.set("n", "<F9>", rhs, {
after/ftplugin/python.lua:72:vim.keymap.set("n", "<leader>cf", rhs, {
lua/config/bufferline.lua:48:vim.keymap.set("n", "<leader>bp", "<cmd>BufferLinePick<CR>", {
lua/config/diffview.lua:7:local prefix_conflicts = "<leader>gC"
after/ftplugin/cpp.vim:7:nnoremap <silent> <buffer> <F9> :call <SID>compile_run_cpp()<CR>
lua/config/nvim_ufo.lua:38:vim.keymap.set("n", "zR", require("ufo").openAllFolds)
lua/config/nvim_ufo.lua:39:vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
lua/config/nvim_ufo.lua:40:vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds)
lua/config/nvim_ufo.lua:41:vim.keymap.set("n", "<leader>K", function()
lua/config/hlslens.lua:26:keymap.set("n", "n", "", {
lua/config/hlslens.lua:32:keymap.set("n", "N", "", {
lua/config/hlslens.lua:49:keymap.set("n", "*", "", {
lua/config/hlslens.lua:68:keymap.set("n", "#", "", {
lua/config/fzf-lua.lua:23:vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Fuzzy find files" })
lua/config/fzf-lua.lua:24:vim.keymap.set("n", "<leader>fg", "<cmd>FzfLua live_grep_native<cr>", { desc = "Fuzzy grep files" })
lua/config/fzf-lua.lua:25:vim.keymap.set(
lua/config/fzf-lua.lua:27:  "<leader>fh",
lua/config/fzf-lua.lua:31:vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua btags<cr>", { desc = "Fuzzy search buffer tags" })
lua/config/fzf-lua.lua:32:vim.keymap.set(
lua/config/fzf-lua.lua:34:  "<leader>fb",
lua/config/fzf-lua.lua:38:vim.keymap.set(
lua/config/fzf-lua.lua:40:  "<leader>fr",
lua/config/git-linker.lua:32:keymap.set({ "n", "v" }, "<leader>gl", function()
lua/config/git-linker.lua:40:keymap.set("n", "<leader>gbr", function()
lua/config/iswap.lua:4:vim.keymap.set("n", "gs<", "<cmd>ISwapWithLeft<cr>")
lua/config/iswap.lua:5:vim.keymap.set("n", "gs>", "<cmd>ISwapWithRight<cr>")
lua/config/treesitter-textobjects.lua:35:vim.keymap.set({ "x", "o" }, "af", function()
lua/config/treesitter-textobjects.lua:38:vim.keymap.set({ "x", "o" }, "if", function()
lua/config/treesitter-textobjects.lua:41:vim.keymap.set({ "x", "o" }, "ac", function()
lua/config/treesitter-textobjects.lua:44:vim.keymap.set({ "x", "o" }, "ic", function()
lua/config/treesitter-textobjects.lua:48:vim.keymap.set({ "x", "o" }, "as", function()
lua/config/nvim-tree.lua:101:keymap.set("n", "<leader>e", require("nvim-tree.api").tree.toggle, {
lua/config/fugitive.lua:3:keymap.set("n", "<leader>gs", "<cmd>Git<cr>", { desc = "Git: show status" })
lua/config/fugitive.lua:4:keymap.set("n", "<leader>gw", "<cmd>Gwrite<cr>", { desc = "Git: add file" })
lua/config/fugitive.lua:5:keymap.set("n", "<leader>gc", "<cmd>Git commit<cr>", { desc = "Git: commit changes" })
lua/config/fugitive.lua:6:keymap.set("n", "<leader>gpl", "<cmd>Git pull<cr>", { desc = "Git: pull changes" })
lua/config/fugitive.lua:7:keymap.set("n", "<leader>gpu", "<cmd>15 split|term git push<cr>", { desc = "Git: push changes" })
lua/config/fugitive.lua:8:keymap.set("v", "<leader>gb", ":Git blame<cr>", { desc = "Git: blame selected line" })
lua/config/fugitive.lua:13:keymap.set("n", "<leader>gbn", function()
lua/config/fugitive.lua:26:keymap.set("n", "<leader>gf", ":Git fetch ", { desc = "Git: prune branches" })
lua/config/fugitive.lua:27:keymap.set("n", "<leader>gbd", ":Git branch -D ", { desc = "Git: delete branch" })
lua/config/gitsigns.lua:16:      vim.keymap.set(mode, l, r, opts)
lua/config/gitsigns.lua:41:    map("n", "<leader>hp", gs.preview_hunk, { desc = "preview hunk" })
lua/config/gitsigns.lua:42:    map("n", "<leader>hb", function()
lua/config/yanky.lua:12:vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)")
lua/config/yanky.lua:13:vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)")
lua/config/yanky.lua:16:vim.keymap.set("n", "[y", "<Plug>(YankyPreviousEntry)")
lua/config/yanky.lua:17:vim.keymap.set("n", "]y", "<Plug>(YankyNextEntry)")
lua/config/glance.lua:10:vim.keymap.set("n", "<leader>lgd", "<cmd>Glance definitions<cr>", { desc = "Glance definitions" })
lua/config/glance.lua:11:vim.keymap.set("n", "<leader>lgr", "<cmd>Glance references<cr>", { desc = "Glance references" })
lua/config/glance.lua:12:vim.keymap.set("n", "<leader>lgi", "<cmd>Glance implementations<cr>", { desc = "Glance implementations" })
lua/config/nvim_hop.lua:13:keymap.set({ "n", "v", "o" }, "<leader>j", "", {
lua/config/which-key.lua:11:  { "<leader>b", group = "buffer" },
lua/config/which-key.lua:12:  { "<leader>c", group = "code/config" },
lua/config/which-key.lua:13:  { "<leader>d", group = "diagnostics" },
lua/config/which-key.lua:14:  { "<leader>f", group = "find" },
lua/config/which-key.lua:15:  { "<leader>g", group = "git" },
lua/config/which-key.lua:16:  { "<leader>h", group = "git hunk" },
lua/config/which-key.lua:17:  { "<leader>l", group = "lsp" },
lua/config/which-key.lua:18:  { "<leader>lg", group = "glance" },
lua/config/which-key.lua:19:  { "<leader>lw", group = "workspace" },
lua/config/which-key.lua:20:  { "<leader>s", group = "system" },
```
