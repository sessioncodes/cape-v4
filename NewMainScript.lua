local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
	writefile(file, '')
end

local BRANCH = 'main'
local REPO = 'https://raw.githubusercontent.com/sessioncodes/capevapecompiled/'

local function getCommit()
	local commit = isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or BRANCH
	if #commit ~= 40 then
		commit = BRANCH
	end
	return commit
end

local function toGithubPath(path)
	return (path:gsub('^newvape/', ''))
end

local function getGithubUrl(path)
	return REPO .. getCommit() .. '/' .. toGithubPath(path)
end

local function downloadFile(path, func)
	if not isfile(path) then
		local url = getGithubUrl(path)

		local suc, res = pcall(function()
			return game:HttpGet(url, true)
		end)

		if not suc or res == '404: Not Found' then
			error('Failed to download: ' .. path .. '\nGitHub URL: ' .. url .. '\nResponse: ' .. tostring(res))
		end

		if path:find('%.lua$') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
		end

		writefile(path, res)
	end

	return (func or readfile)(path)
end

local function githubFileExists(path)
	local url = getGithubUrl(path)

	local suc, res = pcall(function()
		return game:HttpGet(url, true)
	end)

	return suc and res ~= '404: Not Found', res
end

local function downloadGameFile(placeId)
	local path = 'newvape/games/' .. tostring(placeId) .. '.lua'

	if isfile(path) then
		return readfile(path)
	end

	local exists, content = githubFileExists(path)

	if exists then
		writefile(path, content)
		return content
	end

	return nil
end

local function wipeFolder(path)
	if not isfolder(path) then return end

	for _, file in listfiles(path) do
		if file:find('loader') then
			continue
		end

		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {
	'newvape',
	'newvape/games',
	'newvape/profiles',
	'newvape/assets',
	'newvape/libraries',
	'newvape/guis'
} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/sessioncodes/capevapecompiled')
	end)

	local commit = subbed and subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or BRANCH

	local oldCommit = isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or ''

	if commit == BRANCH or oldCommit ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end

	writefile('newvape/profiles/commit.txt', commit)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')()