-- network.lua - Multiplayer networking for Ultimate Tic-Tac-Toe

local M = {}

-- Network state
M.connection = nil
M.server = nil
M.is_host = false
M.is_connected = false
M.opponent_name = nil
M.message_buffer = ""
M.on_message_callback = nil

-- Start hosting a game
-- @param port number: port to listen on (default 9999)
-- @param on_connect function: callback when client connects
-- @return boolean, string: success flag and message/error
function M.start_host(port, on_connect)
  port = port or 9999

  if M.server then
    return false, "Already hosting!"
  end

  local server = vim.loop.new_tcp()
  local success, err = server:bind("0.0.0.0", port)

  if not success then
    return false, "Failed to bind to port " .. port .. ": " .. (err or "unknown error")
  end

  server:listen(128, function(listen_err)
    if listen_err then
      vim.schedule(function()
        vim.notify("Listen error: " .. listen_err, vim.log.levels.ERROR)
      end)
      return
    end

    -- Accept client connection
    local client = vim.loop.new_tcp()
    server:accept(client)

    M.connection = client
    M.is_host = true
    M.is_connected = true

    vim.schedule(function()
      vim.notify("Client connected!", vim.log.levels.INFO)
      if on_connect then
        on_connect()
      end
    end)

    -- Set up message receiving
    M.setup_receive_handler(client)
  end)

  M.server = server
  return true, "Hosting on port " .. port
end

-- Stop hosting
function M.stop_host()
  if M.connection then
    M.send_message({ type = "disconnect", reason = "Host stopped" })
    M.connection:close()
    M.connection = nil
  end

  if M.server then
    M.server:close()
    M.server = nil
  end

  M.is_host = false
  M.is_connected = false
  M.message_buffer = ""
end

-- Connect to a host
-- @param ip string: host IP address
-- @param port number: host port
-- @param on_connect function: callback when connected
-- @return boolean, string: success flag and message/error
function M.connect_to_host(ip, port, on_connect)
  if M.connection then
    return false, "Already connected!"
  end

  local client = vim.loop.new_tcp()

  client:connect(ip, port, function(connect_err)
    if connect_err then
      vim.schedule(function()
        vim.notify("Connection failed: " .. connect_err, vim.log.levels.ERROR)
      end)
      return
    end

    M.connection = client
    M.is_host = false
    M.is_connected = true

    vim.schedule(function()
      vim.notify("Connected to host!", vim.log.levels.INFO)
      if on_connect then
        on_connect()
      end
    end)

    -- Set up message receiving
    M.setup_receive_handler(client)
  end)

  return true, "Connecting to " .. ip .. ":" .. port .. "..."
end

-- Disconnect from host
function M.disconnect()
  if M.connection then
    M.send_message({ type = "disconnect", reason = "Client disconnected" })
    M.connection:close()
    M.connection = nil
  end

  M.is_connected = false
  M.is_host = false
  M.message_buffer = ""

  if M.server then
    M.server:close()
    M.server = nil
  end
end

-- Send a message
-- @param msg_table table: message to send (will be JSON encoded)
function M.send_message(msg_table)
  if not M.connection or not M.is_connected then
    vim.notify("Not connected!", vim.log.levels.ERROR)
    return
  end

  local ok, msg_json = pcall(vim.json.encode, msg_table)
  if not ok then
    vim.notify("Failed to encode message: " .. msg_json, vim.log.levels.ERROR)
    return
  end

  local data = msg_json .. "\n"
  M.connection:write(data)
end

-- Set up message receiving
-- @param socket userdata: TCP socket
function M.setup_receive_handler(socket)
  socket:read_start(function(read_err, chunk)
    if read_err then
      vim.schedule(function()
        vim.notify("Read error: " .. read_err, vim.log.levels.ERROR)
        M.is_connected = false
      end)
      return
    end

    if not chunk then
      -- Connection closed
      vim.schedule(function()
        vim.notify("Opponent disconnected", vim.log.levels.WARN)
        M.is_connected = false
        M.connection = nil
      end)
      return
    end

    -- Buffer incoming data
    M.message_buffer = M.message_buffer .. chunk

    -- Process complete messages (newline-delimited)
    while true do
      local newline_pos = M.message_buffer:find("\n")
      if not newline_pos then
        break
      end

      local msg_json = M.message_buffer:sub(1, newline_pos - 1)
      M.message_buffer = M.message_buffer:sub(newline_pos + 1)

      -- Parse JSON
      local ok, msg = pcall(vim.json.decode, msg_json)
      if ok and msg then
        vim.schedule(function()
          if M.on_message_callback then
            M.on_message_callback(msg)
          end
        end)
      else
        vim.schedule(function()
          vim.notify("Failed to parse message: " .. (msg or "unknown"), vim.log.levels.WARN)
        end)
      end
    end
  end)
end

-- Set message callback
-- @param callback function: function to call when message received
function M.set_message_callback(callback)
  M.on_message_callback = callback
end

-- Convenience function to send a move
-- @param meta_row number: meta board row
-- @param meta_col number: meta board column
-- @param cell_row number: cell row
-- @param cell_col number: cell column
-- @param player string: player ("X" or "O")
function M.send_move(meta_row, meta_col, cell_row, cell_col, player)
  M.send_message({
    type = "move",
    meta_row = meta_row,
    meta_col = meta_col,
    cell_row = cell_row,
    cell_col = cell_col,
    player = player,
  })
end

-- Send game state
-- @param game_state table: full game state to sync
function M.send_game_state(game_state)
  M.send_message({
    type = "game_state",
    boards = game_state.boards,
    meta_board = game_state.meta_board,
    current_player = game_state.current_player,
    active_board = game_state.active_board,
    game_over = game_state.game_over,
    winner = game_state.winner,
  })
end

-- Send reset request
function M.send_reset()
  M.send_message({ type = "reset" })
end

-- Get local IP address
-- @return string: local IP address or error message
function M.get_local_ip()
  local handle
  local os_name = vim.loop.os_uname().sysname

  if os_name == "Darwin" or os_name == "Linux" then
    handle = io.popen("ifconfig 2>/dev/null || ip addr 2>/dev/null")
  elseif os_name == "Windows_NT" then
    handle = io.popen("ipconfig")
  else
    return "Unable to determine IP"
  end

  if not handle then
    return "Unable to get IP address"
  end

  local result = handle:read("*a")
  handle:close()

  -- Try to find local network IP (192.168.x.x or 10.x.x.x)
  local ips = {}

  -- Match patterns for different IP formats
  for ip in result:gmatch("inet%s+(%d+%.%d+%.%d+%.%d+)") do
    if ip ~= "127.0.0.1" and (ip:match("^192%.168%.") or ip:match("^10%.") or ip:match("^172%.")) then
      table.insert(ips, ip)
    end
  end

  -- Also try Windows format
  for ip in result:gmatch("IPv4%s+Address[%.%s:]+(%d+%.%d+%.%d+%.%d+)") do
    if ip ~= "127.0.0.1" and (ip:match("^192%.168%.") or ip:match("^10%.") or ip:match("^172%.")) then
      table.insert(ips, ip)
    end
  end

  if #ips > 0 then
    return table.concat(ips, ", ")
  end

  return "Unable to find local IP (check ifconfig/ipconfig manually)"
end

-- Check connection status
-- @return boolean: true if connected
function M.is_connection_active()
  return M.is_connected
end

return M
