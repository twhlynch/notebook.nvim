local M = {}

--- strip empty lines from the beginning and end of a cell
--- @param source string[]
--- @return string[]
function M.strip_source(source)
	local lines = vim.deepcopy(source)

	if #lines == 0 then
		return lines
	end

	while #lines > 0 and lines[1]:match("^%s*$") do
		table.remove(lines, 1)
	end

	while #lines > 0 and lines[#lines]:match("^%s*$") do
		table.remove(lines)
	end

	if #lines == 0 then
		return { "" }
	end

	return lines
end

--- read lines from a table or string stripping newlines
--- @param data string | string[]
--- @param no_nl? boolean
--- @return string[]
function M.table_or_str_lines(data, no_nl)
	-- lines in table
	if type(data) == "table" then
		local lines = {}

		for _, line in ipairs(data) do
			local clean = tostring(line):gsub("\r", "")
			if not no_nl then
				-- removing trailing newlines from jupyter will be skipped for stderr
				clean = clean:gsub("\n$", "")
			end
			local split = vim.split(clean, "\n")

			for _, part in ipairs(split) do
				table.insert(lines, part)
			end
		end

		return lines
	end

	-- single line
	local clean = tostring(data or ""):gsub("\r", "")
	local split = vim.split(clean, "\n")

	return split
end

--- stripping ansi with lpeg for better performance
--- @return vim.lpeg.Pattern
function M.precompiled_ansi_stripper()
	if not M.ansi_stripper then
		local lpeg = vim.lpeg
		local any = lpeg.P(1)
		local ansi_sequence = lpeg.P("\27[") * lpeg.R("09", ";;") ^ 0 * lpeg.R("az", "AZ")
		local stripper = lpeg.Cs((ansi_sequence / "" + any) ^ 0)
		M.ansi_stripper = stripper
	end

	return M.ansi_stripper
end

--- strip andi codes from a string
--- @param str string
--- @return string
function M.strip_ansi(str)
	if not str or str == "" then
		return str
	end
	return M.precompiled_ansi_stripper():match(str)
end

--- terminal codes parsing
--- @param on_line_ready function
--- @return table
function M.create_terminal_parser(on_line_ready)
	local current_line = ""

	return {
		-- process a new chunk of text
		push = function(text)
			if type(text) == "table" then
				text = table.concat(text, "")
			end

			-- simulate \r \b
			local clean_text = M.strip_ansi(text):gsub("\r\n", "\n")
			for i = 1, #clean_text do
				local c = clean_text:sub(i, i)
				if c == "\n" then
					on_line_ready(current_line)
					current_line = ""
				elseif c == "\r" then
					current_line = ""
				elseif c == "\b" then
					if #current_line > 0 then
						current_line = current_line:sub(1, -2)
					end
				else
					current_line = current_line .. c
				end
			end
		end,

		-- force output of any remaining text in the buffer
		flush = function()
			if current_line ~= "" then
				on_line_ready(current_line)
				current_line = ""
			end
		end,
	}
end

--- debounce util
--- @param func function
function M.debounce(func)
	M.render_timer = M.render_timer or vim.loop.new_timer()
	M.render_timer:stop()
	M.render_timer:start(50, 0, vim.schedule_wrap(func))
end

--- write base64 data to a file
--- @param data string base64 data
--- @param path string file path to save to
--- @return boolean
function M.write_base64_file(data, path)
	local ok, decoded = pcall(vim.base64.decode, data:gsub("%s+", ""))
	if not ok or not decoded then
		return false
	end

	local f = io.open(path, "wb")
	if not f then
		return false
	end

	f:write(decoded)
	f:close()

	return true
end

return M
