-- game.lua - Core game logic and state management for Ultimate Tic-Tac-Toe

local M = {}

-- Create a new game state
-- @param local_player string: "X" or "O" (which player this client is)
-- @param is_multiplayer boolean: true if network game
-- @return table: new game state
function M.new(local_player, is_multiplayer)
  local state = {
    -- 3x3 array of 3x3 arrays (9 small boards, each with 9 cells)
    boards = {},
    -- Meta board tracking which small boards are won
    meta_board = {},
    -- Current player
    current_player = "X",
    -- Active board {row, col} or nil (nil means any board can be played)
    active_board = nil,
    -- Game over flag
    game_over = false,
    -- Winner: nil, "X", "O", or "D" (draw)
    winner = nil,
    -- Which player this client is (for multiplayer)
    local_player = local_player or "X",
    -- Whether this is a multiplayer game
    is_multiplayer = is_multiplayer or false,
  }

  -- Initialize all boards and meta_board
  for i = 0, 2 do
    state.boards[i] = {}
    state.meta_board[i] = {}
    for j = 0, 2 do
      state.boards[i][j] = {}
      state.meta_board[i][j] = nil
      for k = 0, 2 do
        state.boards[i][j][k] = {}
        for l = 0, 2 do
          state.boards[i][j][k][l] = nil
        end
      end
    end
  end

  return state
end

-- Check if a 3x3 board has a winner
-- @param board table: 3x3 board to check
-- @return string: nil (no winner), "X", "O", or "D" (draw)
function M.check_winner(board)
  -- Check rows
  for i = 0, 2 do
    if board[i][0] and board[i][0] == board[i][1] and board[i][1] == board[i][2] then
      return board[i][0]
    end
  end

  -- Check columns
  for j = 0, 2 do
    if board[0][j] and board[0][j] == board[1][j] and board[1][j] == board[2][j] then
      return board[0][j]
    end
  end

  -- Check diagonals
  if board[0][0] and board[0][0] == board[1][1] and board[1][1] == board[2][2] then
    return board[0][0]
  end
  if board[0][2] and board[0][2] == board[1][1] and board[1][1] == board[2][0] then
    return board[0][2]
  end

  -- Check for draw (all filled, no winner)
  local all_filled = true
  for i = 0, 2 do
    for j = 0, 2 do
      if not board[i][j] then
        all_filled = false
        break
      end
    end
    if not all_filled then
      break
    end
  end

  if all_filled then
    return "D"
  end

  return nil
end

-- Check if a board is full
-- @param board table: 3x3 board to check
-- @return boolean: true if all cells are filled
function M.is_board_full(board)
  for i = 0, 2 do
    for j = 0, 2 do
      if not board[i][j] then
        return false
      end
    end
  end
  return true
end

-- Check if a small board is won or full
-- @param state table: game state
-- @param meta_row number: meta board row (0-2)
-- @param meta_col number: meta board column (0-2)
-- @return boolean: true if board is won or full
function M.is_board_finished(state, meta_row, meta_col)
  return state.meta_board[meta_row][meta_col] ~= nil
end

-- Check if a move is valid
-- @param state table: game state
-- @param meta_row number: meta board row (0-2)
-- @param meta_col number: meta board column (0-2)
-- @param cell_row number: cell row within small board (0-2)
-- @param cell_col number: cell column within small board (0-2)
-- @return boolean, string: valid flag and error message
function M.is_valid_move(state, meta_row, meta_col, cell_row, cell_col)
  -- Check if game is over
  if state.game_over then
    return false, "Game is already over!"
  end

  -- Check bounds
  if meta_row < 0 or meta_row > 2 or meta_col < 0 or meta_col > 2 then
    return false, "Invalid board position!"
  end
  if cell_row < 0 or cell_row > 2 or cell_col < 0 or cell_col > 2 then
    return false, "Invalid cell position!"
  end

  -- Check if multiplayer and not your turn
  if state.is_multiplayer and state.current_player ~= state.local_player then
    return false, "Not your turn!"
  end

  -- Check if move is in active board (if set)
  if state.active_board then
    if state.active_board[1] ~= meta_row or state.active_board[2] ~= meta_col then
      return false, "Must play in active board!"
    end
  end

  -- Check if small board is already won or full
  if M.is_board_finished(state, meta_row, meta_col) then
    return false, "This board is already finished!"
  end

  -- Check if cell is empty
  if state.boards[meta_row][meta_col][cell_row][cell_col] then
    return false, "Cell is already occupied!"
  end

  return true, ""
end

-- Make a move
-- @param state table: game state
-- @param meta_row number: meta board row (0-2)
-- @param meta_col number: meta board column (0-2)
-- @param cell_row number: cell row within small board (0-2)
-- @param cell_col number: cell column within small board (0-2)
-- @return boolean, string, table: success flag, message, and move data
function M.make_move(state, meta_row, meta_col, cell_row, cell_col)
  -- Validate move
  local valid, error_msg = M.is_valid_move(state, meta_row, meta_col, cell_row, cell_col)
  if not valid then
    return false, error_msg, nil
  end

  -- Place the mark
  state.boards[meta_row][meta_col][cell_row][cell_col] = state.current_player

  -- Check if small board is won
  local small_board_winner = M.check_winner(state.boards[meta_row][meta_col])
  if small_board_winner then
    state.meta_board[meta_row][meta_col] = small_board_winner
  end

  -- Check if game is won
  local game_winner = M.check_winner(state.meta_board)
  if game_winner then
    state.game_over = true
    state.winner = game_winner
  end

  -- Determine next active board
  -- Next active board is where the move was made in the small board
  local next_meta_row = cell_row
  local next_meta_col = cell_col

  -- Check if next board is finished (won or full)
  if M.is_board_finished(state, next_meta_row, next_meta_col) then
    -- Player can play anywhere
    state.active_board = nil
  else
    state.active_board = { next_meta_row, next_meta_col }
  end

  -- Store move data for network sync
  local move_data = {
    meta_row = meta_row,
    meta_col = meta_col,
    cell_row = cell_row,
    cell_col = cell_col,
    player = state.current_player,
  }

  -- Toggle current player
  state.current_player = state.current_player == "X" and "O" or "X"

  local message = state.game_over and (state.winner == "D" and "Game is a draw!" or ("Player " .. state.winner .. " wins!"))
    or "Move successful"

  return true, message, move_data
end

-- Apply a move received from network (doesn't validate turn)
-- @param state table: game state
-- @param move_data table: move data received from opponent
-- @return boolean, string: success flag and message
function M.apply_remote_move(state, move_data)
  local meta_row = move_data.meta_row
  local meta_col = move_data.meta_col
  local cell_row = move_data.cell_row
  local cell_col = move_data.cell_col
  local player = move_data.player

  -- Basic validation (but don't check turn)
  if state.game_over then
    return false, "Game is already over!"
  end

  if state.boards[meta_row][meta_col][cell_row][cell_col] then
    return false, "Cell is already occupied!"
  end

  -- Place the mark
  state.boards[meta_row][meta_col][cell_row][cell_col] = player

  -- Check if small board is won
  local small_board_winner = M.check_winner(state.boards[meta_row][meta_col])
  if small_board_winner then
    state.meta_board[meta_row][meta_col] = small_board_winner
  end

  -- Check if game is won
  local game_winner = M.check_winner(state.meta_board)
  if game_winner then
    state.game_over = true
    state.winner = game_winner
  end

  -- Determine next active board
  local next_meta_row = cell_row
  local next_meta_col = cell_col

  if M.is_board_finished(state, next_meta_row, next_meta_col) then
    state.active_board = nil
  else
    state.active_board = { next_meta_row, next_meta_col }
  end

  -- Toggle current player
  state.current_player = state.current_player == "X" and "O" or "X"

  local message = state.game_over and (state.winner == "D" and "Game is a draw!" or ("Player " .. state.winner .. " wins!"))
    or "Opponent move received"

  return true, message
end

-- Get active board info for display
-- @param state table: game state
-- @return string: description of active board
function M.get_active_board_message(state)
  if state.active_board then
    return string.format("Active board: (%d, %d)", state.active_board[1] + 1, state.active_board[2] + 1)
  else
    return "Play anywhere!"
  end
end

return M
