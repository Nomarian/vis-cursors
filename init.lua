require"vis"
local vis = vis

local M = {}
local cursors = {}
local files = {}

--[[ TODO:
	files is a dictionary
	open as w+, seek to the number if it exists, save from then on
--]]

-- default cachefile maxsize
M.maxsize = 1000

local Exists = function -- string|false
(
	filepath -- string
)
	return os.rename(filepath, filepath) and filepath or false
end

-- get the default system cache directory
-- (Exists($XDG_CACHE_HOME or $HOME/.cache)/vis-cursors) or $HOME/.vis-cursors
local get_default_cache_path = function()
	local filename = "vis-cursors"
	local HOME = os.getenv('HOME')
	local home = HOME .. "/." .. filename

	-- freedesktop states that if $XDG_CACHE_HOME is not set
	-- $HOME/.cache must be used (if it exists)
	local XDG_CACHE_HOME = Exists(
		os.getenv"XDG_CACHE_HOME"
		or (HOME .. "/.cache")
	)
	if XDG_CACHE_HOME then
		XDG_CACHE_HOME = XDG_CACHE_HOME .. "/" .. filename
		-- move vis-cursors to new location & behavior
		-- this fails, but it doesn't error so it doesn't matter
		os.rename(home, XDG_CACHE_HOME)
		return XDG_CACHE_HOME
	end

	return home
end

-- default save path
M.path = get_default_cache_path()

local read_files = function ()
	local file = io.open(M.path)
	if file == nil then
		return
	end

	-- read positions per file path
	for line in file:lines() do
		local path, pos = string.match(line, '^(.+)[,%s](%d+)$')
		cursors[path] = pos
		table.insert(files, path)
	end

	file:close()
end

-- read cursors from file on init
local on_init = read_files

-- apply cursor pos on win open
local on_win_open = function(win)

	if win.file == nil or win.file.path == nil then
		return
	end

	-- init cursor path if nil
	local pos = cursors[win.file.path]
	if pos == nil then
		cursors[win.file.path] = win.selection.pos
		return
	end

	-- set current cursor
	win.selection.pos = tonumber(pos)

	-- center view around cursor
	vis:feedkeys("zz")
end

-- set cursor pos on close
local on_win_close = function(win)

	if win.file == nil or win.file.path == nil then
		return
	end

	-- re-read files in case they've changed
	read_files()

	-- remove old occurences of current path
	-- TODO: use dictionary?
	for i, path in ipairs(files) do
		if path == win.file.path then
			table.remove(files, i)
		end
	end

	-- ignore files with cursor at the beginning
	if win.selection.pos == 0 then
		return
	end

	-- insert current path to top of files
	table.insert(files, 1, win.file.path)

	-- set cursor pos for current file path
	cursors[win.file.path] = win.selection.pos
end

-- write cursors to file on quit
local on_quit = function()

	local file = io.open(M.path, 'w+')
	if file == nil then
		return
	end

	-- buffer cursors string
	local buffer = {}
	local limit = #files<=M.maxsize and #files or M.maxsize
	for i=1, limit do
		local path = files[i]
		buffer[i] = string.format('%s,%d', path, cursors[path])
	end
	local output = table.concat(buffer, '\n')
	file:write(output)
	file:close()
end

vis.events.subscribe(vis.events.INIT, on_init)
vis.events.subscribe(vis.events.WIN_OPEN, on_win_open)
vis.events.subscribe(vis.events.WIN_CLOSE, on_win_close)
vis.events.subscribe(vis.events.QUIT, on_quit)

return M
