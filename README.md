# Ultimate Tic-Tac-Toe for Neovim

A fully functional Neovim plugin for playing Ultimate Tic-Tac-Toe with a beautiful ASCII interface, complete game logic, and **networked multiplayer support** for playing with friends over LAN/WiFi!

## What is Ultimate Tic-Tac-Toe?

Ultimate Tic-Tac-Toe is a strategic variant of Tic-Tac-Toe where the game board consists of 9 regular Tic-Tac-Toe boards arranged in a 3x3 grid. Players take turns placing their marks (X or O) on any of the small boards, with the goal of winning three small boards in a row to win the game.

The twist: **where you play determines where your opponent must play next!** If you place your mark in a particular cell of a small board, your opponent must play in the corresponding small board on the meta-grid.

## Features

- ?? **Local gameplay** - Two players on the same computer
- ?? **Online multiplayer** - Play with friends over LAN/WiFi
- ?? **Beautiful ASCII interface** - Clean, colorful board display
- ? **Real-time sync** - Moves sync instantly in multiplayer
- ?? **Full game logic** - All Ultimate Tic-Tac-Toe rules implemented
- ?? **Intuitive controls** - Vim-style navigation and simple keybindings
- ?? **Active board highlighting** - See where you can play at a glance
- ?? **Win detection** - Automatic game over detection for wins and draws

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'oliverhnat/ultimateTTC-nvim',
  config = function()
    require('ultimate_tictactoe').setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'oliverhnat/ultimateTTC-nvim',
  config = function()
    require('ultimate_tictactoe').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'oliverhnat/ultimateTTC-nvim'

" In your init.vim or init.lua:
lua require('ultimate_tictactoe').setup()
```

## Usage

### Local Game (Same Computer)

Perfect for quick games or practicing strategy!

```vim
:UltimateTicTacToe
" or the short alias:
:UTTT
```

Two players take turns on the same computer. Player X goes first.

### Multiplayer Game (Different Computers)

Play with friends over LAN/WiFi!

#### As Host (Player X)

1. Start hosting:
   ```vim
   :UTTTHost
   ```

2. The plugin will display your IP address (e.g., `192.168.1.100:9999`)

3. Share this IP and port with your opponent

4. Wait for your opponent to connect

5. Once connected, you play as **X** and go first!

#### As Client (Player O)

1. Join a game:
   ```vim
   :UTTTJoin
   ```

2. Enter the host's IP and port (e.g., `192.168.1.100:9999`)

3. Once connected, you play as **O** and go second!

### Making Moves

1. Navigate to the cell you want to play using `h`, `j`, `k`, `l` (or arrow keys)
2. Press `<Enter>` or `<Space>` to make your move
3. **In multiplayer**: You can only move when it's your turn!
4. Moves sync automatically to your opponent

### Game Controls

| Key | Action |
|-----|--------|
| `<Enter>` or `<Space>` | Place your mark in the current cell |
| `h`, `j`, `k`, `l` | Navigate the board (standard Vim motions) |
| `r` | Reset the game |
| `q` | Quit/close the game (disconnects in multiplayer) |

### Other Commands

```vim
:UTTTReset  " Reset the current game
:UTTTClose  " Close the game and disconnect
```

## Game Rules

### How to Play

1. **First Move**: Player X can play anywhere on any of the 9 small boards

2. **Subsequent Moves**: Where you play determines where your opponent must play next
   - If you play in the top-left cell of a small board, your opponent must play in the top-left small board
   - If you play in the center cell, they must play in the center board
   - And so on...

3. **Winning a Small Board**: Get three in a row (horizontally, vertically, or diagonally) in a small board
   - Once won, the small board is marked with a large X or O
   - No more moves can be made in that board

4. **Play Anywhere**: If you're sent to a board that's already won or full, you can play anywhere!

5. **Winning the Game**: Win three small boards in a row on the meta-board to win!

6. **Draw**: If all 9 small boards are filled/won but no one has three in a row, it's a draw

### Multiplayer Rules

- **Host** is always Player X (goes first)
- **Client** is always Player O (goes second)
- Turn-based: You can only move when it's your turn
- Connection required throughout the game
- If opponent disconnects, the game ends

## Configuration

You can customize the plugin by passing options to `setup()`:

```lua
require('ultimate_tictactoe').setup({
  default_port = 9999,  -- Default port for hosting
  keymaps = {
    make_move = "<CR>",       -- Primary move key
    make_move_alt = "<Space>", -- Alternative move key
    reset = "r",              -- Reset game
    quit = "q"                -- Quit game
  },
})
```

### Custom Highlights

The plugin uses the following highlight groups that you can customize:

```lua
-- In your config:
vim.api.nvim_set_hl(0, "UltimateTTTX", { fg = "#61afef", bold = true })        -- X marks (blue)
vim.api.nvim_set_hl(0, "UltimateTTTO", { fg = "#e06c75", bold = true })        -- O marks (red)
vim.api.nvim_set_hl(0, "UltimateTTTActive", { bg = "#3e4451" })                -- Active board
vim.api.nvim_set_hl(0, "UltimateTTTWon", { fg = "#98c379", bold = true })      -- Won boards
vim.api.nvim_set_hl(0, "UltimateTTTYourTurn", { fg = "#98c379", bold = true }) -- Your turn
vim.api.nvim_set_hl(0, "UltimateTTTOpponentTurn", { fg = "#5c6370" })          -- Opponent's turn
vim.api.nvim_set_hl(0, "UltimateTTTTitle", { fg = "#c678dd", bold = true })    -- Title
```

## Network Requirements

### For Multiplayer Games

- Both players must be on the **same WiFi/LAN network**
- Host must allow incoming connections on the specified port (default: 9999)
- Some firewalls may block connections - you may need to configure your firewall

### Finding Your IP Address

The plugin will display your IP when hosting, but you can also find it manually:

**macOS/Linux:**
```bash
ifconfig
# or
ip addr
```

**Windows:**
```bash
ipconfig
```

Look for addresses like:
- `192.168.x.x` (most common for home networks)
- `10.x.x.x` (also common for local networks)
- `172.16.x.x` - `172.31.x.x` (some networks)

**Don't use** `127.0.0.1` - that's localhost and won't work for multiplayer!

## Troubleshooting

### Connection Issues

**"Connection refused"**
- Check that the host is actually running (`:UTTTHost`)
- Verify the IP address is correct
- Check firewall settings on both computers
- Ensure both computers are on the same network

**"Port already in use"**
- Another program is using port 9999
- Try a different port when hosting

**"Can't find IP address"**
- Run `ifconfig` (Mac/Linux) or `ipconfig` (Windows) manually
- Look for your local network IP (192.168.x.x or 10.x.x.x)

### Connection Dropped

- Network issue - check WiFi signal
- One player quit the game
- Computer went to sleep
- Restart the game and reconnect

### Lag/Delay

- Normal for network games
- Depends on WiFi quality and network traffic
- Try moving closer to the router

### Invalid Move

- **"Not your turn!"** - Wait for your opponent to move
- **"Must play in active board!"** - Check the highlighted board
- **"Cell already occupied!"** - That cell is taken
- **"Board already won!"** - Choose a different board

## Example Game

```
===============================================================
                    ULTIMATE TIC-TAC-TOE                    
===============================================================

Mode: Multiplayer | Connected (Host) | You are: X
Current Player: X (YOUR TURN!)
Active board: (2, 2)

+----------+----------+----------+
|  - - - |  - - - |  - - - |
|  - | - |  - | - |  - | - |
|  - - - |  - - - |  - - - |
+----------+----------+----------+
|  X O - |  - - - |  - - - |
|  - | - |  - | - |  - | - |
|  - - - |  - - - |  - - - |
+----------+----------+----------+
|  - - - |  - - - |  - - - |
|  - | - |  - | - |  X | - |
|  - - - |  - - - |  - - - |
+----------+----------+----------+

Game in progress... Use <CR> to make a move

Controls: <CR>=Move | r=Reset | q=Quit
```

## Development

The plugin is structured as follows:

```
ultimateTTC-nvim/
??? README.md
??? plugin/
?   ??? ultimate_tictactoe.lua  # Command registration
??? lua/
    ??? ultimate_tictactoe/
        ??? init.lua             # Main module
        ??? game.lua             # Game logic
        ??? ui.lua               # Rendering
        ??? network.lua          # Multiplayer networking
```

## Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## Future Enhancements

Some ideas for future versions:

- [ ] Reconnection support
- [ ] Chat system during games
- [ ] Game history/replay
- [ ] Undo moves (with opponent consent)
- [ ] Save/load games
- [ ] Statistics tracking
- [ ] Move timer/clock
- [ ] Sound effects
- [ ] Animations
- [ ] AI opponent
- [ ] Tournament mode

## License

MIT License - feel free to use and modify!

## Credits

Created by oliverhnat

Inspired by the strategic depth of Ultimate Tic-Tac-Toe and the power of Neovim!

---

**Have fun playing! May the best strategist win! ??**
