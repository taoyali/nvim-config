local utils = require("utils")
local fn = vim.fn

local GIT_STATUS_REFRESH_INTERVAL = 30 * 1000
local GIT_FETCH_INTERVAL = 100 * 60

-- Git 状态由后台任务更新，状态栏只读取缓存。
local git_status_cache = {
  behind_count = 0,
  ahead_count = 0,
  fetch_running = false,
  status_running = false,
  last_fetch_at = 0,
}

local async_cmd = function(cmd_str, on_exit)
  local cmd = vim.tbl_filter(function(element)
    return element ~= ""
  end, vim.split(cmd_str, " "))

  vim.system(cmd, { text = true }, on_exit)
end

local function handle_numeric_result(cache_key, on_complete)
  return function(result)
    if result.code == 0 then
      git_status_cache[cache_key] = tonumber(result.stdout:match("(%d+)")) or 0
    else
      git_status_cache[cache_key] = 0
    end
    on_complete()
  end
end

local function update_git_status()
  if git_status_cache.status_running then
    return
  end

  git_status_cache.status_running = true
  local pending = 2
  local function on_complete()
    pending = pending - 1
    git_status_cache.status_running = pending > 0
  end

  async_cmd("git rev-list --count HEAD..@{upstream}", handle_numeric_result("behind_count", on_complete))
  async_cmd("git rev-list --count @{upstream}..HEAD", handle_numeric_result("ahead_count", on_complete))
end

local function fetch_origin_if_due()
  local now = os.time()
  local elapsed = now - git_status_cache.last_fetch_at
  if git_status_cache.fetch_running or elapsed < GIT_FETCH_INTERVAL then
    return
  end

  git_status_cache.last_fetch_at = now
  git_status_cache.fetch_running = true
  async_cmd("git fetch origin", function()
    git_status_cache.fetch_running = false
    update_git_status()
  end)
end

local function refresh_git_status()
  fetch_origin_if_due()
  update_git_status()
  vim.defer_fn(refresh_git_status, GIT_STATUS_REFRESH_INTERVAL)
end

vim.schedule(refresh_git_status)

local function get_git_ahead_behind_info()
  local status = git_status_cache
  if not status then
    return ""
  end

  local msg = ""

  if type(status.ahead_count) == "number" and status.ahead_count > 0 then
    local ahead_str = string.format("↑[%d] ", status.ahead_count)
    msg = msg .. ahead_str
  end

  if type(status.behind_count) == "number" and status.behind_count > 0 then
    local behind_str = string.format("↓[%d] ", status.behind_count)
    msg = msg .. behind_str
  end

  return msg
end

local function spell()
  if vim.o.spell then
    return string.format("[SPELL]")
  end

  return ""
end

--- show indicator for Chinese IME
local function ime_state()
  if vim.g.is_mac then
    -- ref: https://github.com/vim-airline/vim-airline/blob/master/autoload/airline/extensions/xkblayout.vim#L11
    local layout = fn.libcall(vim.g.XkbSwitchLib, "Xkb_Switch_getXkbLayout", "")

    -- We can use `xkbswitch -g` on the command line to get current mode.
    -- mode for macOS builtin pinyin IME: com.apple.inputmethod.SCIM.ITABC
    -- mode for Rime: im.rime.inputmethod.Squirrel.Rime
    local res = fn.match(layout, [[\v(Squirrel\.Rime|SCIM.ITABC)]])
    if res ~= -1 then
      return "[CN]"
    end
  end

  return ""
end

local function trailing_space()
  if not vim.o.modifiable then
    return ""
  end

  local line_num = nil

  for i = 1, fn.line("$") do
    local linetext = fn.getline(i)
    -- To prevent invalid escape error, we wrap the regex string with `[[]]`.
    local idx = fn.match(linetext, [[\v\s+$]])

    if idx ~= -1 then
      line_num = i
      break
    end
  end

  local msg = ""
  if line_num ~= nil then
    msg = string.format("[%d]trailing", line_num)
  end

  return msg
end

local function mixed_indent()
  if not vim.o.modifiable then
    return ""
  end

  local space_pat = [[\v^ +]]
  local tab_pat = [[\v^\t+]]
  local space_indent = fn.search(space_pat, "nwc")
  local tab_indent = fn.search(tab_pat, "nwc")
  local mixed = (space_indent > 0 and tab_indent > 0)
  local mixed_same_line
  if not mixed then
    mixed_same_line = fn.search([[\v^(\t+ | +\t)]], "nwc")
    mixed = mixed_same_line > 0
  end
  if not mixed then
    return ""
  end
  if mixed_same_line ~= nil and mixed_same_line > 0 then
    return "MI:" .. mixed_same_line
  end
  local space_indent_cnt = fn.searchcount({ pattern = space_pat, max_count = 1e3 }).total
  local tab_indent_cnt = fn.searchcount({ pattern = tab_pat, max_count = 1e3 }).total
  if space_indent_cnt > tab_indent_cnt then
    return "MI:" .. tab_indent
  else
    return "MI:" .. space_indent
  end
end

local diff = function()
  local git_status = vim.b.gitsigns_status_dict
  if git_status == nil then
    return
  end

  local modify_num = git_status.changed
  local remove_num = git_status.removed
  local add_num = git_status.added

  local info = { added = add_num, modified = modify_num, removed = remove_num }
  -- vim.print(info)
  return info
end

local virtual_env = function()
  local venv_name = utils.get_virtual_env()

  if venv_name ~= "" then
    return string.format(" (%s)", venv_name)
  else
    return ""
  end
end

local get_active_lsp = function()
  local msg = "🚫"
  local buf_ft = vim.api.nvim_get_option_value("filetype", {})
  local clients = vim.lsp.get_clients { bufnr = 0 }
  if next(clients) == nil then
    return msg
  end

  for _, client in ipairs(clients) do
    ---@diagnostic disable-next-line: undefined-field
    local filetypes = client.config.filetypes
    if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
      return client.name
    end
  end
  return msg
end

require("lualine").setup {
  options = {
    icons_enabled = true,
    theme = "auto",
    component_separators = { left = "|", right = "|" },
    section_separators = "",
    disabled_filetypes = {},
    always_divide_middle = true,
    refresh = {
      statusline = 1000,
    },
  },
  sections = {
    lualine_a = {
      {
        "filename",
        symbols = {
          readonly = "[🔒]",
        },
      },
    },
    lualine_b = {
      {
        "branch",
        fmt = function(name, _)
          -- truncate branch name in case the name is too long
          return string.sub(name, 1, 20)
        end,
        color = { gui = "italic,bold" },
      },
      {
        get_git_ahead_behind_info,
        color = { fg = "#E0C479" },
      },
      {
        "diff",
        source = diff,
      },
      {
        virtual_env,
        color = { fg = "black", bg = "#F1CA81" },
      },
    },
    lualine_c = {
      {
        "%S",
        color = { gui = "bold", fg = "cyan" },
      },
      {
        spell,
        color = { fg = "black", bg = "#a7c080" },
      },
    },
    lualine_x = {
      {
        get_active_lsp,
        icon = "📡",
      },
      {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        symbols = { error = "🆇 ", warn = "⚠️ ", info = "ℹ️ ", hint = " " },
      },
      {
        trailing_space,
        color = "WarningMsg",
      },
      {
        mixed_indent,
        color = "WarningMsg",
      },
    },
    lualine_y = {
      {
        "encoding",
        fmt = string.upper,
      },
      {
        "fileformat",
        symbols = {
          unix = "unix",
          dos = "win",
          mac = "mac",
        },
      },
      "filetype",
      {
        ime_state,
        color = { fg = "black", bg = "#f46868" },
      },
    },
    lualine_z = {
      "location",
      "progress",
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = { "quickfix", "fugitive", "nvim-tree" },
}
