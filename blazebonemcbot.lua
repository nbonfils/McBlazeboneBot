#!/usr/bin/env lua

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

-- op clearance :)
local opIdFile = io.open("opid", "r")
local opId = opIdFile:read("*all")
local op = {}
for i in opId:gmatch("%S+") do op[i] = true end
opIdFile:close()

-- latest.log path
local mcLogPath = "/srv/minecraft/logs/latest.log"
local cleanPattern = ".*%[Server thread/INFO%]: "

-- docker base command
local dockerCmd = "sudo docker exec -e TERM=xterm ftb minecraft console "

-- log file to store output of bot, create "new" blank log file
local botLogPath = "blazebonemcbot.log"
local botLogFile = io.open(botLogPath, "w")
botLogFile:close()

-- MAIN PROGRAMME

-- Function definitions

-- writes the text as a new line to the bot log file
local function writeLog (text)
    local botLogFile = io.open(botLogPath, "a")
    local logPrefix = os.date("[%H:%M:%S] - ")
    botLogFile:write(logPrefix, text, "\n")
    botLogFile:close()
end

-- read the latest logs from the given position (in bytes) untill the eof
local function readLogs (pos)
    -- open log file
    local mcLogFile = io.open(mcLogPath, "r")

    -- check if it is a new log file
    if pos > mcLogFile:seek("end") then
        pos = 0
    end

    mcLogFile:seek("set", pos)

    -- handle logs to notify Telegram
    for line in mcLogFile:lines() do
        local log, match = line:gsub(cleanPattern, "")
        if match >= 0 then

            -- player log in
            if log:match("joined the game") then
                local player = log:gsub(" joined the game", "")
                writeLog("detected a login from player: " .. player)
                bot.sendMessage(chatId, player .. " just connected")

                -- troll
                if player == "Metalskull" or player == "Yaanst" then
                    bot.sendMessage(chatId, "Brace yourselves !\n The admins are playing !")
                elseif player == "Pacco1217" then
                    bot.sendMessage(chatId, "Don't join him... he's a dick 8==D")
                end
            -- player log out
            elseif log:match("left the game") then
                local player = log:gsub(" left the game", "")
                writeLog("detected a logout from player: " .. player)
                bot.sendMessage(chatId, player .. " disconnected")

                -- troll
                if player == "I3ijix" then
                    bot.sendMessage(chatId, "The fucking griefer left, you can play safely now")
                end
            -- server started
            elseif log:match("Done.*For help") then
                writeLog("detected server done loading !")
                bot.sendMessage(chatId, "Server is ready \xE2\x9C\x85")
            -- server stopping
            elseif log:match("Stopping the server") then
                writeLog("detected server shutdown !")
                bot.sendMessage(chatId, "Server is down \xF0\x9F\x9A\xAB")
            end
        end
    end

    pos = mcLogFile:seek("end")
    mcLogFile:close()
    return pos
end

-- get the log file size
local function getLogFileSize ()
    -- open the log file and go to the end
    local mcLogFile = io.open(mcLogPath, "r")
    local size = mcLogFile:seek("end")
    mcLogFile:close()
    return size
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

-- execute a command and read the logs to reply
local function processCmd (cmd, isMultiline)
    local size = getLogFileSize()

    -- use close() otherwise lua does not see mcLogFile changes
    io.popen(dockerCmd .. cmd):close()
    writeLog("Executed: " .. dockerCmd .. cmd)
    os.execute("sleep 1")

    local mcLogFile = io.open(mcLogPath, "r")
    mcLogFile:seek("set", size)

    local response = ""
    if isMultiline then
        writeLog("Answered:")
        for line in mcLogFile:lines() do
            local log = line:gsub(cleanPattern, "")
            writeLog("\t" .. log)
            response = response .. log .. "\n"
        end
    else
        response = mcLogFile:read("*line"):gsub(cleanPattern, "")
        writeLog("Answered: " .. response)
    end
    mcLogFile:close()
    bot.sendMessage(chatId, response)
end

-- handle text messages/commands
extension.onTextReceive = function (msg)
    writeLog("new message by " .. msg.from.first_name .. " : " .. msg.text)
    -- commands executed in the minecraft console output to the log file directly

    -- list online players
    if msg.text == "/list" then
        processCmd("list", true)
    end

    -- get server status
    if msg.text == "/status" then
        local ps = io.popen("sudo docker ps"):read("*all")
        local in_ps = string.find(ps, "ftb")
        local exited = string.find(ps, "Exited")

        local response = ""
        if not in_ps or exited then 
            response = "Server is down \xF0\x9F\x9A\xAB"
        else
            response = "Server is up (maybe not ready yet) \xE2\x9C\x85"
        end
        writeLog("Answered: " .. response)

    end

    -- check CPU temperature levels
    if msg.text == "/sensors" then
        -- use [[ ]] to represent a string that does not escape characters such as \d
        local cmd = [[sensors | grep -P "temp\d" | cut -d "(" -f 1]]
        local response = io.popen(cmd):read("*all"):close()
        writeLog("Executed: " .. cmd)
        writeLog("Answered: ")
        for line in response:lines() do
            writeLog("\t " .. line)
        end
        bot.sendMessage(chatId, response)

    end

    -- check load averages of the server
    if msg.text == "/load" then
        -- use [[ ]] to represent a string that does not escape characters such as \d
        local cmd = [[cat /proc/loadavg | grep -oP "(\d\.\d{2} ){3}"]]
        local response = io.popen(cmd):read("*all"):close()
        writeLog("Executed: " .. cmd)
        writeLog("Answered: " .. response)
        bot.sendMessage(chatId, response)
    end

    -- op commands
    if op[tostring(msg.from.id)] then
        -- manage the whitelist
        if string.find(msg.text,"/whitelist ") then
            -- whitelist options
            if string.find(msg.text, "add") then
                local name = string.gsub(msg.text, "/whitelist add ", "")
                processCmd("whitelist add " .. name, false)

            elseif string.find(msg.text, "remove") then
                local name = string.gsub(msg.text, "/whitelist remove ", "")
                processCmd("whitelist remove " .. name, false)

            elseif string.find(msg.text, "list") then
                processCmd("whitelist list", true)
            end
        end

        -- kick a player
        if string.find(msg.text,"/kick ") then
            local name = string.gsub(msg.text, "/kick ", "")
            processCmd("kick " .. name, false)
        end

        -- ban a player
        if string.find(msg.text,"/ban ") then
            local name = string.gsub(msg.text, "/ban ", "")
            processCmd("ban " .. name, false)
        end

        -- list active bans
        if string.find(msg.text,"/banlist") then
            local entity = string.gsub(msg.text, "/banlist ", "") --entity is "players" or "ips"
            processCmd("banlist " .. entity, true)
        end
        
        -- pardon/unban a player
        if string.find(msg.text,"/pardon ") then
            local name = string.gsub(msg.text, "/pardon ", "")
            processCmd("pardon " .. name, false)
        end

        -- save the world
        if msg.text == "/save" then
            processCmd("save-all", true)
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
    else
        if string.find(msg.text, "/whitelist ")
                or string.find(msg.text, "/kick ")
                or string.find(msg.text, "/ban ")
                or string.find(msg.text, "/banlist")
                or string.find(msg.text, "/pardon ")
                or msg.text == "/save"
                or msg.text == "/restart"
                or msg.text == "/start"
                or msg.text == "/stop" then
            bot.sendMessage(chatId, "HEEEEEEY " .. string.upper(msg.from.first_name) .. " IS A CHEATER, HE TRIED SOME ADMIN COMMANDS !")
            writeLog("non admin user " .. msg.from.first_name .. " tried some admin commands")
        end
    end
end

extension.run()
