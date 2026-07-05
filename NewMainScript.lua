local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/sessioncodes/cape-v4/main/'..path, true)
		end)
		if not suc or res == '404: Not Found' then
			error(res or 'Failed to download: '..path)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

-- Create folders
for _, folder in {'capevape', 'capevape/games', 'capevape/profiles', 'capevape/assets', 'capevape/libraries', 'capevape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

-- Write commit.txt
if not isfile('capevape/profiles/commit.txt') then
	writefile('capevape/profiles/commit.txt', 'main')
end

-- Download and run main script
return loadstring(downloadFile('NewMainScript.lua'), 'NewMainScript')()