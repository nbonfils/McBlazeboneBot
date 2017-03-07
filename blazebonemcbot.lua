
-- VARIABLES DEFINITIONS

-- retrieve the Telegram bot token, so it's not hardcoded
local tokenFile = io.open("token", "r")
local token = tokenFile:read("*all")
tokenFile:close()

-- import the bot framework
local bot, extension = (require "modules.lua-bot-api").configure(token)

-- retrieve chatId of minecraft telegram group
local chatIdFile = io.open("chatid", "r")
local chatId = chatIdFile:read("*all")
chatIdFile:close()

-- define Set data type
function Set (list)
    local set = {}
    for _, l in ipairs(list) do
        set[l] = true
    end
    return set
end

-- op clearance :)
local op = Set { "Nils", "Yann" }

-- latest.log path
local logPath = "/srv/minecraft/logs/latest.log"
local logPath = "example.log"

-- docker base command
local dockerCmd = "sudo docker exec -e TERM=xterm ftb minecraft console "


-- MAIN PROGRAMME

-- read the latest logs from the given position (in bytes) untill the eof
function readLogs (pos)
    -- open log file
    local logFile = io.open(logPath, "r")

    -- check if it is a new log file
    if pos > logFile:seek("end") then
        pos = 0
    end

    logFile:seek("set", pos)

    -- handle logs to notify Telegram
    for line in logFile:lines() do
        local log, match = line:gsub(".*%[Server thread/INFO%]: ", "")
        if match >= 0 then

            -- player log in
            if log:match("joined the game") then
                local player = log:gsub(" joined the game", "")
                bot.sendMessage(chatId, player .. " just connected")
            -- player log out
            elseif log:match("left the game") then
                local player = log:gsub(" left the game", "")
                bot.sendMessage(chatId, player .. " disconnected")
            -- server started
            elseif log:match("Done.*For help") then
                bot.sendMessage(chatId, "Server is ready")
            -- server stopping
            elseif log:match("Stopping the server") then
                bot.sendMessage(chatId, "Server is down :(")
            end
        end
    end


    pos = logFile:seek("end")
    return pos
end

-- override run() to also read server logs
extension.run = function (limit, timeout)
    if limit == nil then limit = 1 end
    if timeout == nil then timeout = 0 end
    local offset = 0
    local logPos = 0
    while true do 
        -- handle Telegram callbacks
        local updates = bot.getUpdates(offset, limit, timeout)
        if(updates) then
            if (updates.result) then
                for key, update in pairs(updates.result) do
                    extension.parseUpdateCallbacks(update)
                    offset = update.update_id + 1
                end
            end
        end

        -- read server logs
        logPos = readLogs(logPos)
    end
end

-- handle text messages/commands
extension.onTextReceive = function (msg)
    print("new message by", msg.from.first_name, ":", msg.text)
    -- commands executed in the minecraft console output to the log file directly

    -- list online players
    if msg.text == "/list" then
        io.popen(dockerCmd .. "list")
        -- TODO: read log file for output
        bot.sendMessage(chatId, players)
    end

    -- get server status
    if msg.text == "/status" then
        local ps = io.popen("sudo docker ps"):read("*all")
        local in_ps = string.find(ps, "ftb")
        local exited = string.find(ps, "Exited")

        if not in_ps or exited then 
            bot.sendMessage(chatId, "Server is down")
        else
            bot.sendMessage(chatId, "Server is up (maybe not ready yet)")
        end

    end
-- TODO: check commands return codes and send message accordingly

    -- op commands
    if op[msg.from.first_name] then
        -- manage the whitelist
        if string.find(msg.text,"/whitelist") then
            -- whitelist options
            if string.find(msg.text, "add") then
                local name = string.gsub(msg.text, "/whitelist add ", "")
                io.popen(dockerCmd .. "whitelist add " .. name)
                

            elseif string.find(msg.text, "remove") then
                local name = string.gsub(msg.text, "/whitelist remove ", "")
                io.popen(dockerCmd .. "whitelist remove " .. name)

            elseif string.find(msg.text, "list") then
                io.popen(dockerCmd .. "whitelist list")
                bot.sendMessage(chatId, players)
            end
        end

        -- kick a player
        if string.find(msg.text,"/kick") then
            local name = string.gsub(msg.text, "/kick ", "")
            io.popen(dockerCmd .. "kick " .. name)
        end

        -- ban a player
        if string.find(msg.text,"/ban") then
            local name = string.gsub(msg.text, "/ban ", "")
            io.popen(dockerCmd .. "ban " .. name)
        end

        -- save the world
        if msg.text == "/save" then
            io.popen(dockerCmd .. "save-all")
        end

        -- restart the container
        if msg.text == "/restart" then
            local err = io.popen("/srv/minecraft/scripts/restart.sh"):read("*all")
            bot.sendMessage(chatId, err)
        end

        -- start the container
        if msg.text == "/start" then
            io.popen("sudo docker start ftb")
        end

        -- stop the container
        if msg.text == "/stop" then
            local err = io.popen("/srv/minecraft/scripts/stop.sh"):read("*all")
            bot.sendMessage(chatId, err)
        end

    end

end

extension.run()
