-- plugin/ultimate_tictactoe.lua - Plugin entry point and command registration

-- Prevent loading twice
if vim.g.loaded_ultimate_tictactoe then
  return
end
vim.g.loaded_ultimate_tictactoe = true

-- Initialize plugin with default configuration
require("ultimate_tictactoe").setup()

-- Register commands
vim.api.nvim_create_user_command("UltimateTicTacToe", function()
  require("ultimate_tictactoe").new_game()
end, {
  desc = "Start a new local Ultimate Tic-Tac-Toe game",
})

vim.api.nvim_create_user_command("UTTT", function()
  require("ultimate_tictactoe").new_game()
end, {
  desc = "Start a new local Ultimate Tic-Tac-Toe game (short alias)",
})

vim.api.nvim_create_user_command("UTTTHost", function()
  require("ultimate_tictactoe").host_game()
end, {
  desc = "Host a multiplayer Ultimate Tic-Tac-Toe game",
})

vim.api.nvim_create_user_command("UTTTJoin", function()
  require("ultimate_tictactoe").join_game()
end, {
  desc = "Join a multiplayer Ultimate Tic-Tac-Toe game",
})

vim.api.nvim_create_user_command("UTTTReset", function()
  require("ultimate_tictactoe").reset()
end, {
  desc = "Reset the current Ultimate Tic-Tac-Toe game",
})

vim.api.nvim_create_user_command("UTTTClose", function()
  require("ultimate_tictactoe").close()
end, {
  desc = "Close the Ultimate Tic-Tac-Toe game",
})
