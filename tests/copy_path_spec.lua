local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

vim.opt.runtimepath:prepend(config_root)
package.path = vim.fs.joinpath(config_root, "lua", "?.lua") .. ";" .. package.path

local failures = {}
local clipboard = {}

local function copy_to_test_clipboard(lines, regtype)
  clipboard.lines = lines
  clipboard.regtype = regtype
end

local function paste_from_test_clipboard()
  return clipboard.lines or {}, clipboard.regtype or "v"
end

vim.g.clipboard = {
  name = "copy-path-test",
  copy = {
    ["+"] = copy_to_test_clipboard,
    ["*"] = copy_to_test_clipboard,
  },
  paste = {
    ["+"] = paste_from_test_clipboard,
    ["*"] = paste_from_test_clipboard,
  },
  cache_enabled = 0,
}

local function test(name, callback)
  local ok, err = pcall(callback)
  if ok then
    print("PASS: " .. name)
  else
    failures[#failures + 1] = string.format("FAIL: %s\n%s", name, err)
  end
end

local function assert_equal(expected, actual)
  if expected ~= actual then
    error(string.format("expected %q, got %q", expected, actual), 2)
  end
end

local temp_root = vim.fn.tempname()
local project_root = vim.fs.joinpath(temp_root, "project")
local node_path = vim.fs.joinpath(project_root, "lua", "target.lua")

vim.fn.mkdir(vim.fs.joinpath(project_root, ".git"), "p")
vim.fn.mkdir(vim.fs.dirname(node_path), "p")
vim.fn.writefile({}, node_path)

vim.cmd("enew")
vim.bo.swapfile = false
vim.api.nvim_buf_set_name(0, vim.fs.joinpath(temp_root, "NvimTree_1"))
vim.bo.filetype = "NvimTree"

package.loaded["nvim-tree.api"] = {
  tree = {
    get_node_under_cursor = function()
      return {
        absolute_path = node_path,
        name = "target.lua",
        type = "file",
      }
    end,
  },
}

dofile(vim.fs.joinpath(config_root, "plugin", "command.lua"))

test("copies the absolute path of the nvim-tree node", function()
  vim.cmd("CopyPath absolute")
  assert_equal(node_path, vim.fn.getreg("+"))
end)

test("copies the project-relative path of the nvim-tree node", function()
  vim.cmd("CopyPath relative")
  assert_equal("<project-root>/lua/target.lua", vim.fn.getreg("+"))
end)

test("copies only the nvim-tree node name", function()
  vim.cmd("CopyPath nameonly")
  assert_equal("target.lua", vim.fn.getreg("+"))
end)

vim.fn.delete(temp_root, "rf")

if #failures > 0 then
  error(table.concat(failures, "\n"))
end
