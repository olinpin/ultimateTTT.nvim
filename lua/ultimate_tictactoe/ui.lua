-- ui.lua - Visual rendering and display for Ultimate Tic-Tac-Toe

local M = {}

-- Create a new game buffer
-- @return number: buffer number
function M.create_game_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "ultimate_tictactoe")
  vim.api.nvim_buf_set_name(bufnr, "Ultimate Tic-Tac-Toe")

  return bufnr
end

-- Set up highlight groups
function M.setup_highlights()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, "UltimateTTTX", { fg = "#61afef", bold = true })
  vim.api.nvim_set_hl(0, "UltimateTTTO", { fg = "#e06c75", bold = true })
  vim.api.nvim_set_hl(0, "UltimateTTTActive", { bg = "#3e4451" })
  vim.api.nvim_set_hl(0, "UltimateTTTWon", { fg = "#98c379", bold = true })
  vim.api.nvim_set_hl(0, "UltimateTTTBorder", { fg = "#5c6370" })
  vim.api.nvim_set_hl(0, "UltimateTTTYourTurn", { fg = "#98c379", bold = true })
  vim.api.nvim_set_hl(0, "UltimateTTTOpponentTurn", { fg = "#5c6370" })
  vim.api.nvim_set_hl(0, "UltimateTTTTitle", { fg = "#c678dd", bold = true })
end

-- Render a small board (3x3 grid)
-- @param board table: 3x3 board
-- @param meta_state string: nil, "X", "O", or "D" (state of meta board)
-- @return table: array of 3 strings (one per line)
function M.render_small_board(board, meta_state)
  if meta_state == "X" then
    return {
      "X   X",
      "  X  ",
      "X   X",
    }
  elseif meta_state == "O" then
    return {
      " OOO ",
      " O O ",
      " OOO ",
    }
  elseif meta_state == "D" then
    return {
      "-----",
      "-----",
      "-----",
    }
  end

  local lines = {}
  for i = 0, 2 do
    local line = ""
    for j = 0, 2 do
      local cell = board[i][j]
      -- Add space separator except before first cell
      if j > 0 then
        line = line .. " "
      end
      
      if cell == "X" then
        line = line .. "X"
      elseif cell == "O" then
        line = line .. "O"
      else
        -- Use | for middle cell, - for others
        if i == 1 and j == 1 then
          line = line .. "|"
        else
          line = line .. "-"
        end
      end
    end
    table.insert(lines, line)
  end

  return lines
end

-- Render the entire game
-- @param bufnr number: buffer number
-- @param game_state table: game state
-- @param network_state table: network module state
function M.render(bufnr, game_state, network_state)
  local lines = {}

  -- Title and player indicator
  local title = "==============================================================="
  local game_title = "                    ULTIMATE TIC-TAC-TOE                    "
  table.insert(lines, title)
  table.insert(lines, game_title)
  table.insert(lines, title)
  table.insert(lines, "")

  -- Multiplayer status
  if game_state.is_multiplayer then
    local network_info = "Mode: Multiplayer"
    if network_state.is_connected then
      network_info = network_info .. " | Connected"
      if network_state.is_host then
        network_info = network_info .. " (Host)"
      else
        network_info = network_info .. " (Client)"
      end
      network_info = network_info .. " | You are: " .. game_state.local_player
    else
      network_info = network_info .. " | Disconnected"
    end
    table.insert(lines, network_info)
  else
    table.insert(lines, "Mode: Local Game")
  end

  -- Turn indicator
  local turn_msg = "Current Player: " .. game_state.current_player
  if game_state.is_multiplayer then
    if game_state.current_player == game_state.local_player then
      turn_msg = turn_msg .. " (YOUR TURN!)"
    else
      turn_msg = turn_msg .. " (Opponent's turn)"
    end
  end
  table.insert(lines, turn_msg)

  -- Active board indicator
  local active_msg = require("ultimate_tictactoe.game").get_active_board_message(game_state)
  table.insert(lines, active_msg)

  table.insert(lines, "")

  -- Render the game board
  -- Top border
  table.insert(lines, "+-------+-------+-------+")

  -- Render each meta row
  for meta_row = 0, 2 do
    -- Get small board lines for this meta row
    local board_lines = { {}, {}, {} }

    for meta_col = 0, 2 do
      -- Safety check for board structure
      if not game_state.boards or not game_state.boards[meta_row] or not game_state.boards[meta_row][meta_col] then
        vim.notify("Game state not properly initialized!", vim.log.levels.ERROR)
        return
      end
      
      local small_board = game_state.boards[meta_row][meta_col]
      local meta_state = game_state.meta_board[meta_row][meta_col]
      local small_lines = M.render_small_board(small_board, meta_state)

      for i = 1, 3 do
        table.insert(board_lines[i], small_lines[i])
      end
    end

    -- Combine small boards horizontally
    for i = 1, 3 do
      local line = "| " .. board_lines[i][1] .. " | " .. board_lines[i][2] .. " | " .. board_lines[i][3] .. " |"
      table.insert(lines, line)
    end

    -- Add separator between meta rows
    if meta_row < 2 then
      table.insert(lines, "+-------+-------+-------+")
    end
  end

  -- Bottom border
  table.insert(lines, "+-------+-------+-------+")

  table.insert(lines, "")

  -- Game status
  if game_state.game_over then
    if game_state.winner == "D" then
      table.insert(lines, "Game Over: It's a DRAW!")
    else
      table.insert(lines, "Game Over: Player " .. game_state.winner .. " WINS!")
    end
  else
    table.insert(lines, "Game in progress... Use <CR> to make a move")
  end

  table.insert(lines, "")
  table.insert(lines, "Controls: <CR>=Move | r=Reset | q=Quit")

  -- Set buffer as modifiable, update content, then set as unmodifiable
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Apply highlights
  M.apply_highlights(bufnr, game_state, network_state)
end

-- Apply syntax highlighting
-- @param bufnr number: buffer number
-- @param game_state table: game state
-- @param network_state table: network module state
function M.apply_highlights(bufnr, game_state, network_state)
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Highlight title
  for i, line in ipairs(lines) do
    if line:match("ULTIMATE TIC%-TAC%-TOE") then
      vim.api.nvim_buf_add_highlight(bufnr, -1, "UltimateTTTTitle", i - 1, 0, -1)
    end
  end

  -- Highlight X and O marks
  for i, line in ipairs(lines) do
    local col = 0
    while true do
      local x_pos = line:find("X", col + 1, true)
      if not x_pos then
        break
      end
      vim.api.nvim_buf_add_highlight(bufnr, -1, "UltimateTTTX", i - 1, x_pos - 1, x_pos)
      col = x_pos
    end

    col = 0
    while true do
      local o_pos = line:find("O", col + 1, true)
      if not o_pos then
        break
      end
      vim.api.nvim_buf_add_highlight(bufnr, -1, "UltimateTTTO", i - 1, o_pos - 1, o_pos)
      col = o_pos
    end
  end

  -- Highlight turn indicator
  for i, line in ipairs(lines) do
    if line:match("YOUR TURN") then
      vim.api.nvim_buf_add_highlight(bufnr, -1, "UltimateTTTYourTurn", i - 1, 0, -1)
    elseif line:match("Opponent's turn") then
      vim.api.nvim_buf_add_highlight(bufnr, -1, "UltimateTTTOpponentTurn", i - 1, 0, -1)
    end
  end

  -- Highlight active board (if set)
  if game_state.active_board and not game_state.game_over then
    local meta_row = game_state.active_board[1]
    local meta_col = game_state.active_board[2]

    -- Calculate line range for active board
    -- Board starts at line 10 (0-indexed: 9)
    local start_line = 9 + meta_row * 4
    local end_line = start_line + 2  -- Only 3 lines per small board (0, 1, 2)

    for line_idx = start_line, end_line do
      if line_idx < #lines then
        local line = lines[line_idx + 1]
        -- Calculate column range for active board
        local start_col = 2 + meta_col * 8
        local end_col = start_col + 5

        vim.api.nvim_buf_add_highlight(bufnr, -1, "UltimateTTTActive", line_idx, start_col, end_col)
      end
    end
  end
end

-- Convert cursor position to game coordinates
-- @param line number: cursor line (1-indexed)
-- @param col number: cursor column (0-indexed)
-- @return table: {meta_row, meta_col, cell_row, cell_col} or nil
function M.get_cell_from_cursor(line, col)
  -- Board starts at line 10 (1-indexed)
  -- Lines: 1-3=title, 4=empty, 5-7=status, 8=empty, 9=top border, 10=first board line
  local board_start_line = 10

  -- Check if cursor is within board area (9 board lines + 2 separators = 11 lines)
  if line < board_start_line or line > board_start_line + 10 then
    return nil
  end

  -- Calculate relative line within board
  local rel_line = line - board_start_line

  -- Determine meta row and cell row
  local meta_row, cell_row

  if rel_line <= 2 then
    meta_row = 0
    cell_row = rel_line
  elseif rel_line == 3 then
    return nil -- Separator line
  elseif rel_line <= 6 then
    meta_row = 1
    cell_row = rel_line - 4
  elseif rel_line == 7 then
    return nil -- Separator line
  elseif rel_line <= 10 then
    meta_row = 2
    cell_row = rel_line - 8
  else
    return nil
  end

  -- Determine meta col and cell col
  -- Format: "| - - - | - - - | - - - |"
  --         012345678901234567890123
  -- Board 0: cols 2-6 (cells at 2, 4, 6)
  -- Board 1: cols 10-14 (cells at 10, 12, 14)
  -- Board 2: cols 18-22 (cells at 18, 20, 22)

  local meta_col, cell_col

  if col >= 2 and col <= 6 then
    meta_col = 0
    local rel_col = col - 2
    cell_col = math.floor(rel_col / 2)
  elseif col >= 10 and col <= 14 then
    meta_col = 1
    local rel_col = col - 10
    cell_col = math.floor(rel_col / 2)
  elseif col >= 18 and col <= 22 then
    meta_col = 2
    local rel_col = col - 18
    cell_col = math.floor(rel_col / 2)
  else
    return nil
  end

  -- Validate cell_col is within bounds
  if cell_col < 0 or cell_col > 2 then
    return nil
  end

  return { meta_row, meta_col, cell_row, cell_col }
end

-- Show connection dialog
-- @param callback function: callback with choice ("host" or "join")
function M.show_connection_dialog(callback)
  local choices = { "Host Game", "Join Game", "Cancel" }

  vim.ui.select(choices, {
    prompt = "Multiplayer Options:",
  }, function(choice)
    if choice == "Host Game" then
      callback("host")
    elseif choice == "Join Game" then
      callback("join")
    end
  end)
end

-- Show host waiting dialog
-- @param ip string: local IP address
-- @param port number: listening port
function M.show_waiting_dialog(ip, port)
  local msg = string.format("Waiting for opponent to connect...\n\nShare this with your opponent:\nIP: %s\nPort: %d", ip, port)
  vim.notify(msg, vim.log.levels.INFO)
end

-- Prompt for connection details
-- @param callback function: callback with ip and port
function M.prompt_connection_details(callback)
  vim.ui.input({
    prompt = "Enter host IP:Port (e.g., 192.168.1.100:9999): ",
  }, function(input)
    if not input or input == "" then
      return
    end

    -- Parse IP:Port
    local ip, port_str = input:match("([^:]+):(%d+)")
    if not ip or not port_str then
      vim.notify("Invalid format! Use IP:Port (e.g., 192.168.1.100:9999)", vim.log.levels.ERROR)
      return
    end

    local port = tonumber(port_str)
    if not port then
      vim.notify("Invalid port number!", vim.log.levels.ERROR)
      return
    end

    callback(ip, port)
  end)
end

return M
