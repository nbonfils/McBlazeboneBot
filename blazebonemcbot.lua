
-- VARIABLES DEFINITIONS

-- retrive the Telegram bot token, so it's not hardcoded
local tokenFile = io.open("token", "r")
local token = tokenFile:read("*all")

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

-- MAIN PROGRAMME

function readLogs (pos)
    -- TODO
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

-- read server log and notify telegram
-- TODO

extension.run()
