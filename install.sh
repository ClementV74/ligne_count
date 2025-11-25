#!/usr/bin/env bash

set -e

NVIM_CONFIG="$HOME/.config/nvim"
CUSTOM_DIR="$NVIM_CONFIG/lua/custom"
PLUGIN_DIR="$CUSTOM_DIR/cfunc_lines"
PLUGIN_FILE="$PLUGIN_DIR/init.lua"
CUSTOM_INIT="$CUSTOM_DIR/init.lua"

echo "Installing cfunc_lines plugin for NVChad..."

mkdir -p "$PLUGIN_DIR"

cat > "$PLUGIN_FILE" << 'EOF'
local M = {}

local ts = vim.treesitter
local ns = vim.api.nvim_create_namespace("c_func_lines")

local function is_ignorable(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then return true end
  if trimmed == "{" or trimmed == "}" then return true end
  if trimmed:match("^//") then return true end
  if trimmed:match("^/%*") then return true end
  return false
end

local function count_function_lines(bufnr, func_node)
  local start_row, _, end_row, _ = func_node:range()

  local count = 0
  for row = start_row + 1, end_row do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row+1, false)[1] or ""
    if not is_ignorable(line) then
      count = count + 1
    end
  end
  return count, start_row
end

local function setup_highlight()
  vim.cmd([[
    highlight CFuncLineCount guifg=#ffaf5f gui=bold
  ]])
end

function M.update()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "c" then return end

  local parser = ts.get_parser(bufnr, "c", {})
  if not parser then return end
  local tree = parser:parse()[1]
  local root = tree:root()

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local query = ts.query.parse("c", [[
    (function_definition
      declarator: (function_declarator)
    ) @func
  ]])

  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local count, start_row = count_function_lines(bufnr, node)

    vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, 0, {
      virt_text = {{"  " .. count .. " lines", "CFuncLineCount"}},
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end
end

function M.enable_autorefresh()
  setup_highlight()
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "BufEnter", "BufWritePost"}, {
    callback = function() M.update() end,
  })
end

vim.api.nvim_create_user_command("CountCFunctionLines", function()
  M.update()
end, {})

return M
EOF

echo "Configuring NVChad..."

if [ ! -f "$CUSTOM_INIT" ]; then
  echo 'require("custom.cfunc_lines").enable_autorefresh()' > "$CUSTOM_INIT"
else
  if ! grep -q 'custom.cfunc_lines' "$CUSTOM_INIT"; then
    echo 'require("custom.cfunc_lines").enable_autorefresh()' >> "$CUSTOM_INIT"
  fi
fi

echo "Installation complete."
