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
mcLogPath = "example.log"
local cleanPattern = ".*%[Server thread/INFO%]: "

-- docker base command
local dockerCmd = "sudo docker exec -e TERM=xterm ftb minecraft console "

-- MAIN PROGRAMME

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


    pos = mcLogFile:seek("end")
    mcLogFile:close()
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

-- get the log file size
local function getLogFileSize ()
    -- open the log file and go to the end
    local mcLogFile = io.open(mcLogPath, "r")
    local size = mcLogFile:seek("end")
    mcLogFile:close()
    return size
end

-- handle text messages/commands
extension.onTextReceive = function (msg)
    print("new message by", msg.from.first_name, ":", msg.text)
    -- commands executed in the minecraft console output to the log file directly

    -- list online players
    if msg.text == "/list" then
        local size = getLogFileSize()
        
        --use close() otherwise lua does not see mcLogFile changes
        io.popen(dockerCmd .. "list"):close() 
        os.execute('sleep 1') --sleep to make sure logs are written before we read
        
        -- Go just before console command output
        local mcLogFile = io.open(mcLogPath, "r")
        mcLogFile:seek("set", size)

        -- create response from logs
        local response = ""
        for line in mcLogFile:lines() do
            local log = line:gsub(cleanPattern, "")
            response = response .. log .. "\n"
        end
        mcLogFile:close()
        bot.sendMessage(chatId, response)
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
    if op[tostring(msg.from.id)] then
        -- manage the whitelist
        if string.find(msg.text,"/whitelist") then
            -- whitelist options
            if string.find(msg.text, "add") then
                local name = string.gsub(msg.text, "/whitelist add ", "")
                local size = getLogFileSize()

                io.popen(dockerCmd .. "whitelist add " .. name):close()
                os.execute("sleep 1")
                
                local mcLogFile = io.open(mcLogPath, "r")
                mcLogFile:seek("set", size)
                local response = mcLogFile:read("*line"):gsub(cleanPattern, "")
                mcLogFile:close()
                
                bot.sendMessage(chatId, response)


            elseif string.find(msg.text, "remove") then
                local name = string.gsub(msg.text, "/whitelist remove ", "")
                local size = getLogFileSize()

                io.popen(dockerCmd .. "whitelist remove " .. name):close()
                os.execute("sleep 1")
                
                local mcLogFile = io.open(mcLogPath, "r")
                mcLogFile:seek("set", size)
                local response = mcLogFile:read("*line"):gsub(cleanPattern, "")
                mcLogFile:close()
                
                bot.sendMessage(chatId, response)


            elseif string.find(msg.text, "list") then
                local size = getLogFileSize()

                io.popen(dockerCmd .. "whitelist list"):close()
                os.execute('sleep 1')
                
                local mcLogFile = io.open(mcLogPath, "r")
                mcLogFile:seek("set", size)

                -- create response from logs
                local response = ""
                for line in mcLogFile:lines() do
                    local log = line:gsub(cleanPattern, "")
                    response = response .. log .. "\n"
                end
                mcLogFile:close()

                bot.sendMessage(chatId, response)
            end
        end

        -- kick a player
        if string.find(msg.text,"/kick") then
            local name = string.gsub(msg.text, "/kick ", "")
            local size = getLogFileSize()

            io.popen(dockerCmd .. "kick " .. name):close()
            os.execute('sleep 1')

            local mcLogFile = io.open(mcLogPath, "r")
            mcLogFile:seek("set", size)
            local response = mcLogFile:read("*line"):gsub(cleanPattern, "")
            mcLogFile:close()
            
            bot.sendMessage(chatId, response)
            
        end

        -- ban a player
        if string.find(msg.text,"/ban") then
            local name = string.gsub(msg.text, "/ban ", "")
            local size = getLogFileSize()

            io.popen(dockerCmd .. "ban " .. name):close()
            os.execute('sleep 1')

            local mcLogFile = io.open(mcLogPath, "r")
            mcLogFile:seek("set", size)
            local response = mcLogFile:read("*line"):gsub(cleanPattern, "")
            mcLogFile:close()
            
            bot.sendMessage(chatId, response)
        end

        -- list active bans
        if string.find(msg.text,"/banlist") then
            local entity = string.gsub(msg.text, "/ban ", "") --entity is "players" or "ips"
            local size = getLogFileSize()

            io.popen(dockerCmd .. "banlist " .. entity):close()
            os.execute("sleep 1")

            local mcLogFile = io.open(mcLogPath, "r")
            mcLogFile:seek("set", size)

            -- create response from logs
            local response = ""
            for line in mcLogFile:lines() do
                local log = line:gsub(cleanPattern, "")
                response = response .. log .. "\n"
            end
            mcLogFile:close()

            bot.sendMessage(chatId, response)
        end
        
        -- pardon/unban a player
        if string.find(msg.text,"/pardon") then
            local name = string.gsub(msg.text, "/pardon ", "")
            local size = getLogFileSize()
            
            io.popen(dockerCmd .. "pardon " .. name):close()
            os.execute('sleep 1')

            local mcLogFile = io.open(mcLogPath, "r")
            mcLogFile:seek("set", size)
            local response = mcLogFile:read("*line"):gsub(cleanPattern, "")
            mcLogFile:close()
            
            bot.sendMessage(chatId, response)
        end

        -- save the world
        if msg.text == "/save" then
            local size = getLogFileSize()

            io.popen(dockerCmd .. "save-all"):close()
            os.execute("sleep 1")

            local response = ""
            for line in mcLogFile:lines() do
                local log = line:gsub(cleanPattern, "")
                response = response .. log .. "\n"
            end
            mcLogFile:close()

            bot.sendMessage(chatId, response)
        end

        -- restart the container
        if msg.text == "/restart" then
            local err = io.popen("/srv/minecraft/scripts/restart.sh"):read("*all"):close()
            bot.sendMessage(chatId, err)
        end

        -- start the container
        if msg.text == "/start" then
            local err = io.popen("sudo docker start ftb"):read("*all"):close()
            bot.sendMessage(chatId, err)
        end

        -- stop the container
        if msg.text == "/stop" then
            local err = io.popen("/srv/minecraft/scripts/stop.sh"):read("*all"):close()
            bot.sendMessage(chatId, err)
        end

    end

end

extension.run()
