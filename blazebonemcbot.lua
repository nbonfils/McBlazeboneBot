
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
