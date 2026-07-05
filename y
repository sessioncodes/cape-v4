local commit = readfile('newvape/profiles/commit.txt')
print('Commit: ' .. commit)
print('URL: https://raw.githubusercontent.com/sessioncodes/capevapecompiled/' .. commit .. '/newvape/main.lua')
print(game:HttpGet('https://raw.githubusercontent.com/sessioncodes/capevapecompiled/' .. commit .. '/newvape/main.lua', true))