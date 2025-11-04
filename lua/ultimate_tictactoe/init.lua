-- init.lua - Main module for Ultimate Tic-Tac-Toe

local game = require("ultimate_tictactoe.game")
local ui = require("ultimate_tictactoe.ui")
local network = require("ultimate_tictactoe.network")

local M = {}

-- Module state
M.current_game = nil
M.current_buffer = nil
M.config = {}

-- Helper function to convert JSON string-keyed tables to numeric-indexed tables
local function json_to_game_boards(json_boards)
  local boards = {}
  for i = 0, 2 do
    boards[i] = {}
    local i_key = tostring(i)
    for j = 0, 2 do
      boards[i][j] = {}
      local j_key = tostring(j)
      for k = 0, 2 do
        boards[i][j][k] = {}
        local k_key = tostring(k)
        for l = 0, 2 do
          local l_key = tostring(l)
          -- Try both numeric and string keys
          local val = json_boards[i] and json_boards[i][j] and json_boards[i][j][k] and json_boards[i][j][k][l]
          if not val then
            val = json_boards[i_key] and json_boards[i_key][j_key] and json_boards[i_key][j_key][k_key] and json_boards[i_key][j_key][k_key][l_key]
          end
          boards[i][j][k][l] = val
        end
      end
    end
  end
  return boards
end

local function json_to_meta_board(json_meta)
  local meta = {}
  for i = 0, 2 do
    meta[i] = {}
    local i_key = tostring(i)
    for j = 0, 2 do
      local j_key = tostring(j)
      -- Try both numeric and string keys
      local val = json_meta[i] and json_meta[i][j]
      if val == nil then
        val = json_meta[i_key] and json_meta[i_key][j_key]
      end
      meta[i][j] = val
    end
  end
  return meta
end

-- Default configuration
local default_config = {
  default_port = 9999,
  keymaps = {
    make_move = "<CR>",
    make_move_alt = "<Space>",
    reset = "r",
    quit = "q",
  },
}

-- Setup the plugin
-- @param opts table: configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  ui.setup_highlights()
end

-- Set up buffer-local keymaps
-- @param bufnr number: buffer number
local function setup_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, noremap = true }

  vim.keymap.set("n", M.config.keymaps.make_move, function()
    M.make_move()
  end, opts)

  vim.keymap.set("n", M.config.keymaps.make_move_alt, function()
    M.make_move()
  end, opts)

  vim.keymap.set("n", M.config.keymaps.reset, function()
    M.reset()
  end, opts)

  vim.keymap.set("n", M.config.keymaps.quit, function()
    M.close()
  end, opts)
end

-- Create or reuse game buffer
local function get_or_create_buffer()
  if M.current_buffer and vim.api.nvim_buf_is_valid(M.current_buffer) then
    return M.current_buffer
  end

  local bufnr = ui.create_game_buffer()
  M.current_buffer = bufnr
  setup_keymaps(bufnr)

  return bufnr
end

-- Open the game buffer in a window
local function open_game_window(bufnr)
  -- Try to find existing window with the buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  -- Open in current window
  vim.api.nvim_set_current_buf(bufnr)
end

-- Render the current game state
local function render_game()
  if not M.current_game or not M.current_buffer then
    return
  end

  ui.render(M.current_buffer, M.current_game, network)
end

-- Handle incoming network messages
-- @param msg table: decoded message
function M.handle_network_message(msg)
  if not M.current_game then
    return
  end

  if msg.type == "move" then
    -- Debug: Log received move
    vim.notify(string.format("Received move: meta(%s,%s) cell(%s,%s) player=%s", 
      tostring(msg.meta_row), tostring(msg.meta_col), 
      tostring(msg.cell_row), tostring(msg.cell_col), 
      tostring(msg.player)), vim.log.levels.DEBUG)
    
    -- Apply opponent's move
    local success, message = game.apply_remote_move(M.current_game, msg)
    if success then
      render_game()
      if M.current_game.game_over then
        vim.notify(message, vim.log.levels.INFO)
      end
    else
      vim.notify("Error applying opponent's move: " .. message, vim.log.levels.ERROR)
    end
  elseif msg.type == "game_state" then
    -- Sync full game state - preserve local_player and is_multiplayer
    if msg.boards and msg.meta_board then
      local saved_local_player = M.current_game.local_player
      local saved_is_multiplayer = M.current_game.is_multiplayer
      
      -- Convert JSON tables to proper numeric-indexed tables
      M.current_game.boards = json_to_game_boards(msg.boards)
      M.current_game.meta_board = json_to_meta_board(msg.meta_board)
      M.current_game.current_player = msg.current_player
      M.current_game.active_board = msg.active_board
      M.current_game.game_over = msg.game_over or false
      M.current_game.winner = msg.winner
      M.current_game.local_player = saved_local_player
      M.current_game.is_multiplayer = saved_is_multiplayer
      
      render_game()
      vim.notify("Game state synchronized! You are player " .. saved_local_player, vim.log.levels.INFO)
    else
      vim.notify("Received invalid game state!", vim.log.levels.ERROR)
    end
  elseif msg.type == "reset" then
    -- Handle reset request from opponent
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Opponent wants to reset the game. Accept?",
    }, function(choice)
      if choice == "Yes" then
        M.current_game = game.new(M.current_game.local_player, true)
        render_game()
        network.send_game_state(M.current_game)
        vim.notify("Game reset!", vim.log.levels.INFO)
      end
    end)
  elseif msg.type == "disconnect" then
    vim.notify("Opponent disconnected: " .. (msg.reason or "unknown reason"), vim.log.levels.WARN)
    network.disconnect()
  end
end

-- Start a new local game
function M.new_game()
  -- Disconnect from network if connected
  if network.is_connection_active() then
    network.disconnect()
  end

  M.current_game = game.new("X", false)
  local bufnr = get_or_create_buffer()
  open_game_window(bufnr)
  render_game()

  vim.notify("New local game started!", vim.log.levels.INFO)
end

-- Host a multiplayer game
function M.host_game()
  -- Disconnect from existing connection
  if network.is_connection_active() then
    network.disconnect()
  end

  -- Prompt for port
  vim.ui.input({
    prompt = "Enter port (default 9999): ",
    default = tostring(M.config.default_port),
  }, function(port_str)
    if not port_str or port_str == "" then
      port_str = tostring(M.config.default_port)
    end

    local port = tonumber(port_str)
    if not port then
      vim.notify("Invalid port number!", vim.log.levels.ERROR)
      return
    end

    -- Start hosting
    local success, message = network.start_host(port, function()
      -- Client connected - start game
      M.current_game = game.new("X", true)
      render_game()

      -- Send initial game state after a small delay to ensure client is ready
      vim.defer_fn(function()
        network.send_game_state(M.current_game)
        vim.notify("Game state sent to client", vim.log.levels.INFO)
      end, 100)
    end)

    if not success then
      vim.notify("Failed to host: " .. message, vim.log.levels.ERROR)
      return
    end

    -- Create initial game state for hosting (before client connects)
    M.current_game = game.new("X", true)
    local bufnr = get_or_create_buffer()
    open_game_window(bufnr)
    
    -- Render the waiting screen with IP info
    render_game()

    -- Set up message handler
    network.set_message_callback(M.handle_network_message)
  end)
end

-- Join a multiplayer game
function M.join_game()
  -- Disconnect from existing connection
  if network.is_connection_active() then
    network.disconnect()
  end

  -- Prompt for connection details
  ui.prompt_connection_details(function(ip, port)
    -- Connect to host
    local success, message = network.connect_to_host(ip, port, function()
      -- Connected - create initial game as player O but wait for sync
      M.current_game = game.new("O", true)
      local bufnr = get_or_create_buffer()
      open_game_window(bufnr)
      -- Don't render yet - wait for game state from host
      vim.notify("Connected! Waiting for game state from host...", vim.log.levels.INFO)
    end)

    if not success then
      vim.notify("Failed to connect: " .. message, vim.log.levels.ERROR)
      return
    end

    vim.notify(message, vim.log.levels.INFO)

    -- Set up message handler
    network.set_message_callback(M.handle_network_message)
  end)
end

-- Make a move at cursor position
function M.make_move()
  if not M.current_game or not M.current_buffer then
    vim.notify("No active game!", vim.log.levels.WARN)
    return
  end

  if M.current_game.game_over then
    vim.notify("Game is over! Press 'r' to reset or 'q' to quit.", vim.log.levels.INFO)
    return
  end

  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  -- Convert to game coordinates
  local coords = ui.get_cell_from_cursor(line, col)
  if not coords then
    vim.notify("Invalid cursor position! Move cursor to a cell.", vim.log.levels.WARN)
    return
  end

  local meta_row, meta_col, cell_row, cell_col = coords[1], coords[2], coords[3], coords[4]

  -- Attempt move
  local success, message, move_data = game.make_move(M.current_game, meta_row, meta_col, cell_row, cell_col)

  if not success then
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  -- Send move to opponent if multiplayer
  if M.current_game.is_multiplayer and network.is_connection_active() then
    network.send_move(move_data.meta_row, move_data.meta_col, move_data.cell_row, move_data.cell_col, move_data.player)
  end

  -- Re-render
  render_game()

  -- Show game over message
  if M.current_game.game_over then
    vim.notify(message, vim.log.levels.INFO)
  end
end

-- Reset the current game
function M.reset()
  if not M.current_game then
    vim.notify("No active game!", vim.log.levels.WARN)
    return
  end

  if M.current_game.is_multiplayer and network.is_connection_active() then
    -- In multiplayer, ask opponent to reset
    network.send_reset()
    vim.notify("Reset request sent to opponent...", vim.log.levels.INFO)

    -- Reset locally
    M.current_game = game.new(M.current_game.local_player, true)
    render_game()
  else
    -- Local game - just reset
    M.current_game = game.new(M.current_game.local_player, M.current_game.is_multiplayer)
    render_game()
    vim.notify("Game reset!", vim.log.levels.INFO)
  end
end

-- Close the game
function M.close()
  -- Disconnect from network if connected
  if network.is_connection_active() then
    network.disconnect()
    vim.notify("Disconnected from game", vim.log.levels.INFO)
  end

  -- Close buffer if valid
  if M.current_buffer and vim.api.nvim_buf_is_valid(M.current_buffer) then
    vim.api.nvim_buf_delete(M.current_buffer, { force = true })
  end

  M.current_game = nil
  M.current_buffer = nil
end

return M
