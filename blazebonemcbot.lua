-- retrive the Telegram bot token, so it's not hardcoded
local tokenFile = io.open("token", "r")
local token = tokenFile:read("*all")

-- import the bot framework
local bot, extension = (require "modules.lua-bot-api").configure(token)

-- handle text message/commands
extension.onTextReceive = function (msg)
    print("new message by", msg.from.first_name, ":", msg.text)
end

extension.run()
