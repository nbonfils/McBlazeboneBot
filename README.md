# BlazeboneMcBot
A Lua Telegram bot which gives info about our minecraft server.

## Dependencies
Despite using the modules already included, this bot uses *luasec* and *luasocket*.

```bash
luarocks install --local luasec
luarocks install --local luasocket
```

## Troubleshooting
### lua can't find local tree
`eval $(luarocks path --bin)` solve this for current terminal, 
add to `.bashrc`, `.zshrc` or whatever for permanent solution.
