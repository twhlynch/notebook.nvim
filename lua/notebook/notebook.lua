local bridge = require("notebook.bridge")
local constants = require("notebook.constants")
local jupyter = require("notebook.jupyter")
local lualine = require("notebook.lualine")
local renderer = require("notebook.renderer")
local sessions = require("notebook.sessions")
local utils = require("notebook.utils")

local M = {}

--- notebook setup
function M.setup()
	M.group = vim.api.nvim_create_augroup("NotebookPlugin", { clear = true })

	-- most setup will be per file
	vim.api.nvim_create_autocmd("BufReadCmd", {
		pattern = "*.ipynb",
		group = M.group,
		callback = M.setup_file,
	})
end

--- sync all """ and # """ delimiters after a cell change
--- @param state Notebook.Sessions.session
--- @param cells table
function M.sync_buffer(state, cells)
	local notebook_lines = {}

	for i, cell in ipairs(cells) do
		local src = cell.source

		local delimeter = cell.type == "markdown" and '"""' or ""

		-- borders
		table.insert(notebook_lines, delimeter)
		vim.list_extend(notebook_lines, src)
		table.insert(notebook_lines, delimeter)

		-- code to code
		if cell.type == "code" then
			local next_c = cells[i + 1]
			if next_c and next_c.type == "code" then
				table.insert(notebook_lines, '# """')
			end
		end
	end

	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, notebook_lines)
end

--- get the index of the cell containing the cursor
--- @param state Notebook.Sessions.session
--- @return integer | nil
function M.get_current_cell_index(state)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

	-- top line will get above
	if cursor_line == 0 then
		return 0
	end

	-- ensure parsed cells are up to date
	M.parse_buffer(state)

	for i, c in ipairs(state.parsed_cells) do
		if cursor_line >= c.start_line and cursor_line <= (c.end_line + 1) then
			return i
		end
	end

	return nil
end

--- insert a cell under the current cell
--- @param state Notebook.Sessions.session
--- @param cell_type Notebook.Jupyter.CellType
function M.insert_cell(state, cell_type)
	local options = require("notebook.options").get()
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local current_idx = M.get_current_cell_index(state) or #cells

	-- new blank cell
	local source = cell_type == "code" and options.strings.new_code_cell or options.strings.new_cell
	local new_cell = { type = cell_type, source = source }

	-- insert directly below current
	local insert_idx = current_idx + 1
	table.insert(cells, insert_idx, new_cell)

	-- sync state
	table.insert(state.output_store, insert_idx, {})
	if state.snacks_images then
		table.insert(state.snacks_images, insert_idx, {})
	else
		state.snacks_images = { [insert_idx] = {} }
	end

	-- sync buffer
	M.sync_buffer(state, cells)
	M.rerender(state)

	-- move cursor into the new cell
	local target_cell = state.parsed_cells[insert_idx]
	if target_cell then
		-- middle for code, start for md
		vim.api.nvim_win_set_cursor(0, { target_cell.start_line + 1 + (cell_type == "code" and 1 or 0), 0 })
	end

	-- insert mode eol
	vim.cmd(options.new_cell_cmd)
end

--- collect output text content for a given cell index
--- @param state Notebook.Sessions.session
--- @param cell_idx integer
--- @return string[]
local function collect_output_content(state, cell_idx)
	local content = {}
	local parser = utils.create_terminal_parser(function(line)
		table.insert(content, line)
	end)

	for _, out in ipairs(state.output_store[cell_idx] or {}) do
		local text = out.text or (out.data and out.data["text/plain"])
		if text then
			parser.push(text)
		end
	end
	parser.flush()

	return content
end

--- convert the current cells output into a new markdown cell
--- @param state Notebook.Sessions.session
function M.output_to_markdown(state)
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local cell_idx = M.get_current_cell_index(state)

	if cell_idx == 0 then
		cell_idx = 1
	end

	if not cell_idx then
		return
	end

	local content = collect_output_content(state, cell_idx)
	if #content == 0 then
		return
	end

	-- create the new markdown cell
	local new_cell = { type = "markdown", source = content }
	local insert_idx = cell_idx + 1
	table.insert(cells, insert_idx, new_cell)

	-- sync state
	table.insert(state.output_store, insert_idx, {})
	if state.snacks_images then
		table.insert(state.snacks_images, insert_idx, {})
	else
		state.snacks_images = { [insert_idx] = {} }
	end

	-- sync buffer
	M.sync_buffer(state, cells)
	M.rerender(state)

	-- move cursor into the new cell
	local target_cell = state.parsed_cells[insert_idx]
	if target_cell then
		vim.api.nvim_win_set_cursor(0, { target_cell.start_line + 1, 0 })
	end
end

--- convert all cells output into markdown
--- @param state Notebook.Sessions.session
function M.output_to_markdown_all(state)
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local inserted = 0

	-- iterate backward to avoid index shifting
	for i = #cells, 1, -1 do
		local content = collect_output_content(state, i)
		if #content > 0 then
			local new_cell = { type = "markdown", source = content }
			local insert_idx = i + 1
			table.insert(cells, insert_idx, new_cell)

			table.insert(state.output_store, insert_idx, {})
			if state.snacks_images then
				table.insert(state.snacks_images, insert_idx, {})
			else
				state.snacks_images = { [insert_idx] = {} }
			end

			inserted = inserted + 1
		end
	end

	if inserted == 0 then
		return
	end

	M.sync_buffer(state, cells)
	M.rerender(state)
end

--- toggle the current cell type between code and markdown
--- @param state Notebook.Sessions.session
function M.toggle_cell_type(state)
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local idx = M.get_current_cell_index(state)

	if idx == 0 then
		idx = 1
	end

	if not idx then
		return
	end

	local cell = cells[idx]
	local was_code = cell.type == "code"
	cell.type = was_code and "markdown" or "code"

	if was_code then
		state.output_store[idx] = {}
		renderer.clear_images(state, idx)
	end

	M.sync_buffer(state, cells)
	M.rerender(state)

	-- keep cursor in same cell
	local target = state.parsed_cells[idx]
	if target then
		vim.api.nvim_win_set_cursor(0, { target.start_line + 1, 0 })
	end
end

--- remove the current cell
--- @param state Notebook.Sessions.session
function M.remove_cell(state)
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local current_idx = M.get_current_cell_index(state)

	-- first line returns 0
	if current_idx == 0 then
		current_idx = 1
	end

	if not current_idx then
		return
	end

	-- prevent completely clearing the file
	if #cells <= 1 then
		cells[1].source = { "" }
	else
		table.remove(cells, current_idx)
		table.remove(state.output_store, current_idx)
		if state.snacks_images then
			renderer.clear_images(state, current_idx)
			table.remove(state.snacks_images, current_idx)
		end
	end

	-- apply cleanly to buffer
	M.sync_buffer(state, cells)
	M.rerender(state)

	-- fallback cursor to the cell that took its place, or the new bottom cell
	local target_idx = math.min(current_idx, #state.parsed_cells)
	local target_cell = state.parsed_cells[target_idx]
	if target_cell then
		vim.api.nvim_win_set_cursor(0, { target_cell.start_line + 1, 0 })
	end
end

--- split the current cell into two of its same type
--- @param state Notebook.Sessions.session
function M.split_cell(state)
	M.parse_buffer(state)
	local cells = state.parsed_cells

	local idx = M.get_current_cell_index(state)
	-- first line returns 0
	if idx == 0 then
		idx = 1
	end
	if not idx then
		return
	end

	local cell = cells[idx]

	-- cursor position relative to cell
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local rel = cursor_line - cell.start_line

	-- clamp
	if rel < 0 then
		rel = 0
	end
	if rel > #cell.source then
		rel = #cell.source
	end

	-- split source
	local top = {}
	local bottom = {}

	for i, line in ipairs(cell.source) do
		if i < rel then
			table.insert(top, line)
		elseif i == rel then
			if #line > 0 then
				table.insert(top, line)
			end
		else
			table.insert(bottom, line)
		end
	end

	-- add blank line to empty cells
	if #top == 0 then
		top = { "" }
	end
	if #bottom == 0 then
		bottom = { "" }
	end

	-- replace current cell and insert new one
	cells[idx].source = top

	local new_cell = {
		type = cell.type,
		source = bottom,
	}

	table.insert(cells, idx + 1, new_cell)

	-- sync output
	table.insert(state.output_store, idx + 1, {})
	state.snacks_images = state.snacks_images or {}
	table.insert(state.snacks_images, idx + 1, {})

	-- sync buffer
	M.sync_buffer(state, cells)
	M.rerender(state)

	-- move cursor to new cell start
	local new_parsed = state.parsed_cells[idx + 1]
	if new_parsed then
		vim.api.nvim_win_set_cursor(0, { new_parsed.start_line + 1, 0 })
	end
end

--- move the current cell up or down
--- @param state Notebook.Sessions.session
--- @param direction "up" | "down"
function M.move_cell(state, direction)
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local current_idx = M.get_current_cell_index(state)

	if current_idx == 0 then
		current_idx = 1
	end

	if not current_idx then
		return
	end

	local target_idx = direction == "up" and (current_idx - 1) or (current_idx + 1)

	if target_idx < 1 or target_idx > #cells then
		return
	end

	-- swap cells
	cells[current_idx], cells[target_idx] = cells[target_idx], cells[current_idx]
	-- swap output_store
	state.output_store[current_idx], state.output_store[target_idx] = state.output_store[target_idx], state.output_store[current_idx]

	-- swap snacks_images if exists
	if state.snacks_images then
		-- clear from ui as they will be re-drawn
		renderer.clear_images(state, current_idx)
		renderer.clear_images(state, target_idx)
		state.snacks_images[current_idx], state.snacks_images[target_idx] = state.snacks_images[target_idx], state.snacks_images[current_idx]
	end

	-- sync and render
	M.sync_buffer(state, cells)
	M.rerender(state)

	-- move cursor to new position
	local new_cell = state.parsed_cells[target_idx]
	if new_cell then
		vim.api.nvim_win_set_cursor(0, { new_cell.start_line + 1, 0 })
	end
end

--- open the current cells output in a floating window
--- @param state Notebook.Sessions.session
function M.open_output(state)
	-- get cell containing cursor
	local cell_idx = M.get_current_cell_index(state)

	-- first line returns 0
	if cell_idx == 0 then
		cell_idx = 1
	end

	-- check it has output
	if not cell_idx or not state.output_store[cell_idx] then
		return
	end

	-- collect output text content
	local content = {}

	-- terminal parser to push lines into content
	local parser = utils.create_terminal_parser(function(line)
		table.insert(content, line)
	end)

	-- feed outputs into the parser
	for _, out in ipairs(state.output_store[cell_idx]) do
		-- text output
		local text = out.text or (out.data and out.data["text/plain"])
		if text then
			parser.push(text)
		end

		-- error output
		if out.output_type == "error" or out.traceback then
			parser.flush()
			local error_text = table.concat(utils.table_or_str_lines(out.traceback), "\n")
			local clean = utils.strip_ansi(error_text)
			parser.push(clean)
		end
	end
	-- flush remaining text
	parser.flush()

	-- check content length
	if #content == 0 then
		return
	end

	-- create floating window
	local fbuf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, content)

	-- center, 80% max size, content height
	local w = math.floor(vim.o.columns * 0.8)
	local h = math.min(#content + 2, math.floor(vim.o.lines * 0.8))
	local row = (vim.o.lines - h) / 2
	local col = (vim.o.columns - w) / 2

	-- open
	vim.api.nvim_open_win(fbuf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = row,
		col = col,
	})

	-- q or esc to quit
	local opt = { buf = fbuf, silent = true }
	vim.keymap.set("n", "q", "<cmd>close<CR>", opt)
	vim.keymap.set("n", "<ESC>", "<cmd>close<CR>", opt)
end

--- open the current cells images in the system image viewer
--- @param state Notebook.Sessions.session
function M.gx_handler(state)
	local options = require("notebook.options").get()

	-- get cell containing cursor
	local cell_idx = M.get_current_cell_index(state)

	-- first line returns 0
	if cell_idx == 0 then
		cell_idx = 1
	end

	local image_count = M.count_images(state)
	if image_count >= options.image_warn_threshold then
		local prompt = string.format(constants.strings.images_warning, image_count)
		local choice = vim.fn.confirm(prompt, "&No\n&Yes", 1)
		if choice ~= 2 then
			return
		end
	end

	-- check it has output
	if not cell_idx or not state.output_store[cell_idx] then
		if options.keys.open_image == "gx" then
			vim.cmd("normal! gx")
		end
		return
	end

	local handled = false
	for _, out in ipairs(state.output_store[cell_idx]) do
		-- check for image data
		local img_data = out.data and (out.data["image/png"] or out.data["image/jpeg"])
		if img_data then
			-- clean data
			local clean_data = img_data:gsub("%s+", "")
			local tmp = vim.fn.tempname() .. ".png"

			-- write to temp file
			local ok = utils.write_base64_file(clean_data, tmp)
			if ok then
				vim.ui.open(tmp)
				handled = true
			end
		end
	end

	-- fallback to normal gx
	if not handled and options.keys.open_image == "gx" then
		vim.cmd("normal! gx")
	end
end

--- clear the output of all cells
--- @param state Notebook.Sessions.session
function M.clear_output(state)
	-- clear visually
	renderer.clear_ouput(state)

	for i, _ in ipairs(state.parsed_cells) do
		-- clear output
		state.output_store[i] = {}
		-- clear images
		state.snacks_images[i] = {}
	end

	lualine.refresh()
end

--- go to the bottom of the currently running cell
--- @param state Notebook.Sessions.session
function M.go_to_running_cell(state)
	local idx = state.execution_queue[1]
	if not idx then
		return
	end

	M.parse_buffer(state)
	local cell = state.parsed_cells[idx]
	if not cell then
		return
	end

	vim.api.nvim_win_set_cursor(0, { cell.end_line + 1, 0 })
end

--- jump to the next or previous cell
--- @param state Notebook.Sessions.session
--- @param next boolean
function M.jump_cell(state, next)
	M.parse_buffer(state)

	local idx = M.get_current_cell_index(state)

	-- first line returns 0
	if idx == 0 then
		idx = 1
	end

	if not idx then
		return
	end

	local target = next and (idx + 1) or (idx - 1)
	local cell = state.parsed_cells[target]
	if not cell then
		return
	end

	vim.api.nvim_win_set_cursor(0, { cell.start_line + 1, 0 })
end

--- parses the cells from buffer content
--- @param state Notebook.Sessions.session
function M.parse_buffer(state)
	-- read lines
	local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)

	-- starting state
	local cells, current_acc, in_md = {}, {}, false
	local start_idx = 0

	-- helper
	local function emit(end_idx)
		local source = utils.strip_source(current_acc)
		-- markdown cells and code cells with content
		if in_md or #source > 0 then
			table.insert(cells, {
				type = in_md and "markdown" or "code",
				source = source,
				start_line = start_idx,
				end_line = end_idx,
			})
		end
	end

	-- parse lines
	for i, line in ipairs(lines) do
		if line:match('^"""%s*$') then
			emit(i - 2)
			current_acc, start_idx, in_md = {}, i, not in_md
		elseif line:match('^# """%s*$') and not in_md then
			emit(i - 2)
			current_acc, start_idx, in_md = {}, i, false
		else
			table.insert(current_acc, line)
		end
	end
	emit(#lines - 1)

	-- update state with result
	state.parsed_cells = cells
end

--- save the ipynb file
--- @param state Notebook.Sessions.session
function M.save(state)
	local options = require("notebook.options").get()

	-- get the current cell contents
	M.parse_buffer(state)
	local cells = state.parsed_cells

	--- @type Notebook.Jupyter.Cell[]
	local json_cells = {}
	for i, cell in ipairs(cells) do
		local source_lines = utils.table_or_str_lines(cell.source)

		-- cell lines ending with newlines
		local formatted_src = {}
		for idx, line in ipairs(source_lines) do
			-- uncomment magics
			local save_line = line
			if cell.type == "code" and line:match("^# %%") then
				save_line = line:gsub("^# ", "")
			end

			local nl = (idx == #source_lines and "" or "\n")
			table.insert(formatted_src, save_line .. nl)
		end

		-- cell outputs with type
		local clean_outputs = {}

		if options.write_output then
			local cell_outputs = state.output_store[i] or {}
			for _, out in ipairs(cell_outputs) do
				if out.output_type then
					table.insert(clean_outputs, out)
				end
			end
		end

		-- append cell info with content
		--- @type Notebook.Jupyter.Cell
		local cell_data = {
			cell_type = cell.type,
			metadata = vim.empty_dict(),
			source = formatted_src,
			id = tostring(i - 1),
		}
		if cell.type == "code" then
			cell_data.outputs = clean_outputs
			cell_data.execution_count = vim.NIL
		end
		table.insert(json_cells, cell_data)
	end

	-- update raw cells
	state.raw_json.cells = json_cells

	-- write to source file
	local f = io.open(state.path, "w")
	if f then
		local ok, encoded = pcall(vim.json.encode, state.raw_json)
		if ok then
			local f_ok, formatted = pcall(vim.fn.system, "jq --indent 1 --sort-keys .", encoded)
			if f_ok then
				f:write(formatted)
				f:close()
				vim.bo[state.bufnr].modified = false
			end
		end
	end
end

--- parse raw notebook json data into the custom notebook format
--- @param data string | string[]
--- @return string[], table
function M.parse_notebook_data(data)
	local raw_data = type(data) == "table" and table.concat(data, "\n") or data
	local ok, raw_json = pcall(vim.json.decode, raw_data)
	if not ok then
		raw_json = jupyter.blank_notebook()
	end

	-- construct editable notebook content
	local notebook_lines = {}
	for i, cell in ipairs(raw_json.cells) do
		-- read cell source content
		local src = utils.table_or_str_lines(cell.source)
		local stripped = utils.strip_source(src)
		-- comment in empty code cells
		if #stripped == 0 and cell.cell_type == "code" then
			table.insert(stripped, "# empty")
		end

		-- handle magics by commenting them out
		local processed_source = {}
		for _, line in ipairs(stripped) do
			if cell.cell_type == "code" and line:match("^%%") then
				table.insert(processed_source, "# " .. line)
			else
				table.insert(processed_source, line)
			end
		end

		-- surround markdown cells in docstrings and code in newlines
		local delimeter = cell.cell_type == "markdown" and '"""' or ""

		table.insert(notebook_lines, delimeter)
		vim.list_extend(notebook_lines, processed_source)
		table.insert(notebook_lines, delimeter)

		if cell.cell_type == "code" then
			local next_c = raw_json.cells[i + 1]
			if next_c and next_c.cell_type == "code" then
				table.insert(notebook_lines, '# """')
			end
		end
	end

	return notebook_lines, raw_json
end

--- read a notebook and setup the buffer
--- @param state Notebook.Sessions.session
function M.read_file(state)
	local raw_lines = vim.fn.readfile(state.path)
	local notebook_lines, raw_json = M.parse_notebook_data(raw_lines)
	state.raw_json = raw_json

	for i, cell in ipairs(raw_json.cells) do
		-- read existing cell output
		state.output_store[i] = cell.outputs or {}
		if #state.output_store[i] > 0 then
			state.output_store[i].executed = true
		end
	end

	-- set notebook buffer content
	vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, notebook_lines)
end

--- run a range of cells
--- @param state Notebook.Sessions.session
--- @param mode "all" | "up" | "down" | "current"
function M.run_cells(state, mode)
	-- get cells content
	M.parse_buffer(state)
	local all_cells = state.parsed_cells

	-- get current cell
	local current_idx = M.get_current_cell_index(state)

	if current_idx == 0 then
		current_idx = 1
	end

	if not current_idx and mode ~= "all" then
		return
	end

	-- cells to run based on mode
	local mode_indices = {
		all = vim.fn.range(1, #all_cells),
		up = vim.fn.range(1, current_idx),
		down = vim.fn.range(current_idx, #all_cells),
		current = { current_idx },
	}
	local indices = mode_indices[mode]

	bridge.run_cells(state, indices)
end

--- run current cell, then jump to next cell
--- @param state Notebook.Sessions.session
function M.run_then_next(state)
	M.run_cells(state, "current")

	local idx = M.get_current_cell_index(state)

	-- first line returns 0
	if idx == 0 then
		idx = 1
	end

	if not idx then
		return
	end

	local target = idx + 1
	while target <= #state.parsed_cells do
		local cell = state.parsed_cells[target]
		if not cell then
			return
		end

		if cell.type == "code" then
			vim.api.nvim_win_set_cursor(0, { cell.start_line + 1, 0 })
			return
		end

		target = target + 1
	end
end

--- reparse the buffer cells and rerender
--- @param state Notebook.Sessions.session
function M.rerender(state)
	M.parse_buffer(state)
	renderer.render(state)
end

--- count the images in all cell outputs
--- @param state Notebook.Sessions.session
--- @return integer
function M.count_images(state)
	local count = 0

	for _, cell_outputs in pairs(state.output_store or {}) do
		for _, out in ipairs(cell_outputs) do
			local has_image_data = out.data and (out.data["image/png"] or out.data["image/jpeg"])
			if has_image_data then
				count = count + 1
			end
		end
	end

	return count
end

--- save all images to `/figures`
--- @param state Notebook.Sessions.session
function M.dump_images(state)
	local choice = vim.fn.confirm(constants.strings.images_prompt, "&No\n&Yes", 1)
	if choice ~= 2 then
		return
	end

	local cwd = vim.fn.getcwd()

	-- ensure /figures exists
	local directory = cwd .. "/figures"
	if vim.fn.isdirectory(directory) == 0 then
		vim.fn.mkdir(directory)
	end

	-- count images to format with right amount of leading zeros
	local figure_count = M.count_images(state)

	-- at least one leading zero
	local padding = math.max(#tostring(figure_count), 2)

	-- save images
	local figure_index = 1

	for _, cell_outputs in ipairs(state.output_store or {}) do
		for _, out in ipairs(cell_outputs) do
			local img_data = out.data and (out.data["image/png"] or out.data["image/jpeg"])
			if img_data then
				local ext = out.data["image/png"] and "png" or "jpg"
				local dest_path = string.format("%s/figure_%0" .. padding .. "d.%s", directory, figure_index, ext)

				utils.write_base64_file(img_data, dest_path)

				figure_index = figure_index + 1
			end
		end
	end

	vim.notify(vim.fn.printf(constants.strings.saved_images, figure_index - 1))
end

--- format the current cell by piping its source through a command
--- @param state Notebook.Sessions.session
function M.format_cell(state)
	local options = require("notebook.options").get()
	M.parse_buffer(state)
	local cells = state.parsed_cells
	local current_idx = M.get_current_cell_index(state)

	if current_idx == 0 then
		current_idx = 1
	end

	if not current_idx then
		return
	end

	local cell = cells[current_idx]
	if cell.type ~= "code" then
		return
	end

	local source_text = table.concat(cell.source, "\n")

	if source_text:match("^%s*$") then
		return
	end

	local formatted = vim.fn.system(options.format_command, source_text)

	if vim.v.shell_error ~= 0 then
		vim.notify("Format failed: " .. formatted, vim.log.levels.ERROR)
		return
	end

	local formatted_lines = vim.split(formatted, "\n", { plain = true })

	while #formatted_lines > 0 and formatted_lines[#formatted_lines] == "" do
		table.remove(formatted_lines)
	end

	if #formatted_lines == 0 then
		formatted_lines = { "" }
	end

	cell.source = formatted_lines

	M.sync_buffer(state, cells)
	M.rerender(state)
end

--- select the current cell
--- @param state Notebook.Sessions.session
function M.select_cell(state)
	local current_idx = M.get_current_cell_index(state)

	if current_idx == 0 then
		current_idx = 1
	end

	local cell = state.parsed_cells[current_idx]
	local start, finish = cell.start_line + 1, cell.end_line + 1

	-- end first so cursor finishes at end
	vim.fn.setpos("'>", { 0, finish, vim.fn.col({ finish, "$" }), 0 })
	vim.fn.setpos("'<", { 0, start, 1, 0 })
	vim.cmd("normal! gv")
end

--- setup a file
--- @param args vim.api.keyset.create_autocmd.callback_args
function M.setup_file(args)
	local options = require("notebook.options").get()
	local bufnr = vim.api.nvim_get_current_buf()
	local state = sessions.get_state(bufnr)

	-- set state file
	state.path = args.file

	-- use hl overrides
	renderer.apply_highlights(vim.api.nvim_get_current_win())

	-- read file content
	if vim.uv.fs_stat(state.path) ~= nil then
		M.read_file(state)
		M.parse_buffer(state)
	else
		state.raw_json = jupyter.blank_notebook()
	end

	-- buffer options
	vim.bo[state.bufnr].modified = false
	vim.bo[state.bufnr].filetype = "python"
	vim.bo[state.bufnr].buftype = ""
	vim.bo[state.bufnr].modifiable = true

	M.rerender(state)

	-- keybinds
	local keymap = function(modes, leader, name, func, ...)
		local vargs = { ... }
		local key = options.keys[name]
		local desc = constants.strings[name .. "_desc"]
		vim.keymap.set(modes, (leader and options.keybind_prefix or "") .. key, function()
			func(state, unpack(vargs))
		end, { buf = bufnr, silent = true, desc = desc })
	end

	-- stylua: ignore start
	keymap({ "n" },      true,  "run_cell",           M.run_cells, "current"    ) -- running
	keymap({ "n" },      true,  "run_cells_all",      M.run_cells, "all"        )
	keymap({ "n" },      true,  "run_cells_up",       M.run_cells, "up"         )
	keymap({ "n" },      true,  "run_cells_down",     M.run_cells, "down"       )
	keymap({ "n" },      true,  "run_then_next",      M.run_then_next           )
	keymap({ "n" },      true,  "clear_all_output",   M.clear_output            ) -- output
	keymap({ "n" },      true,  "refresh_all_output", M.rerender                )
	keymap({ "n" },      false, "open_image",         M.gx_handler              ) -- viewing
	keymap({ "n" },      false, "show_output",        M.open_output             )
	keymap({ "n" },      false, "next_cell",          M.jump_cell, true         ) -- navigation
	keymap({ "n" },      false, "previous_cell",      M.jump_cell, false        )
	keymap({ "o", "x" }, false, "textobject_cell",    M.select_cell             )
	keymap({ "n" },      true,  "go_to_running_cell", M.go_to_running_cell      )
	keymap({ "n" },      true,  "insert_markdown",    M.insert_cell, "markdown" ) -- editing cells
	keymap({ "n" },      true,  "insert_code",        M.insert_cell, "code"     )
	keymap({ "n" },      true,  "output_to_md",       M.output_to_markdown      )
	keymap({ "n" },      true,  "output_to_md_all",   M.output_to_markdown_all  )
	keymap({ "n" },      true,  "remove_cell",        M.remove_cell             )
	keymap({ "n" },      true,  "toggle_cell_type",   M.toggle_cell_type        )
	keymap({ "n" },      true,  "split_cell",         M.split_cell              )
	keymap({ "n" },      true,  "move_cell_up",       M.move_cell, "up"         )
	keymap({ "n" },      true,  "move_cell_down",     M.move_cell, "down"       )
	keymap({ "n" },      true,  "dump_images",        M.dump_images             ) -- utils
	keymap({ "n" },      true,  "format_cell",        M.format_cell             )
	-- stylua: ignore end

	-- override :w with custom save
	vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
		group = M.group,
		buffer = bufnr,
		callback = function()
			M.save(state)
		end,
	})

	-- render events
	local last_tick = vim.b.changedtick
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = M.group,
		buffer = bufnr,
		callback = function()
			last_tick = vim.b.changedtick
		end,
	})
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = M.group,
		buffer = bufnr,
		callback = function()
			if vim.b.changedtick ~= last_tick then
				M.rerender(state)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "WinResized" }, {
		group = M.group,
		buffer = bufnr,
		callback = function()
			M.rerender(state)
		end,
	})

	-- trigger autocommands
	vim.api.nvim_exec_autocmds("BufReadPost", { buffer = bufnr })
	vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = bufnr })
end

return M
