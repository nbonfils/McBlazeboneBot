
-- VARIABLES DEFINITIONS

-- retrieve the Telegram bot token, so it's not hardcoded
local tokenFile = io.open("token", "r")
local token = tokenFile:read("*all")
tokenFile:close()

-- import the bot framework
local bot, extension = (require "modules.lua-bot-api").configure(token)

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

-- docker basic command
local dockerCmd = "sudo docker exec -e TERM=xterm ftb minecraft console "

-- MAIN PROGRAMME
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

-- read server log and notify telegram
-- TODO

extension.run()
