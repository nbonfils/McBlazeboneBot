
-- VARIABLES DEFINITIONS

-- retrive the Telegram bot token, so it's not hardcoded
local tokenFile = io.open("token", "r")
local token = tokenFile:read("*all")

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
    for line in logFile:lines(l) do
        local log, match = line:gsub(".*%[Server thread/INFO%]: ", "")
        if match >= 0 then

            -- player log in
            if log:match("joined the game") then
                local player = log:gsub(" joined the game", "")
                bot.send(chatId, player .. " just connected")
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
        local updates = M.getUpdates(offset, limit, timeout)
        if(updates) then
            if (updates.result) then
                for key, update in pairs(updates.result) do
                    parseUpdateCallbacks(update)
                    offset = update.update_id + 1
                end
            end
        end

        -- read server logs
        logPos = readLogs(logPos)
    end
end

-- handle text message/commands
extension.onTextReceive = function (msg)
    print("new message by", msg.from.first_name, ":", msg.text)

    -- list online players
    if msg.text == "/list" then
        -- TODO
    end

    -- op commands
    if op[msg.from.first_name] then
        -- TODO
    end

end

extension.run()
