local M = {}

local utils = require("notebook.utils")

--- renderer setup
function M.setup()
	-- create namespaces
	M.output_ns = vim.api.nvim_create_namespace("nb_extmarks_output")
	M.border_ns = vim.api.nvim_create_namespace("nb_extmarks_border")
	M.hl_ns = vim.api.nvim_create_namespace("nb_highlights")

	-- make docstrings white
	vim.api.nvim_set_hl(M.hl_ns, "@string.documentation.python", { link = "Normal" })

	-- replace docstrings with markdown
	-- stylua: ignore
	vim.treesitter.query.set("python", "injections", [[
		((expression_statement
		   (string
		     (string_content) @injection.content) @docstring)
		 (#set! injection.language "markdown")
		 (#set! injection.combined))
	]])
end

--- apply highlights to a window
--- @param window integer
function M.apply_highlights(window)
	vim.api.nvim_win_set_hl_ns(window, M.hl_ns)
end

--- clear a namespace from a buffer
--- @param bufnr integer buffer id
--- @param ns integer namespace id
function M.clear_namespace(bufnr, ns)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

--- main render function, rerenders all cells
--- @param state Notebook.Sessions.session
function M.render(state)
	utils.debounce(function()
		-- clear extmarks
		M.clear_namespace(state.bufnr, M.output_ns)
		M.clear_namespace(state.bufnr, M.border_ns)

		-- render each cell
		for i, _ in ipairs(state.parsed_cells) do
			M.render_cell(state, i)
		end
	end)
end

--- remove cells images from the UI
--- @param state Notebook.Sessions.session
--- @param index integer cell id
function M.clear_images(state, index)
	if state.snacks_images and state.snacks_images[index] then
		for _, img in ipairs(state.snacks_images[index]) do
			img:close()
		end
	end
end

--- remove all images from the UI
--- @param state Notebook.Sessions.session
function M.clear_all_images(state)
	for _, imgs in pairs(state.snacks_images or {}) do
		for _, img in ipairs(imgs) do
			img:close()
		end
	end
end

--- clear all output
--- @param state Notebook.Sessions.session
function M.clear_ouput(state)
	-- clear extmarks
	M.clear_namespace(state.bufnr, M.output_ns)

	-- clear images
	M.clear_all_images(state)
end

--- utility for building virtual line content
--- @param tble any[]
--- @param type "success" | "output" | "error" | "truncation" | "image" | "running"
--- @param text? any
function M.insert_virtual_line(tble, type, text)
	local options = require("notebook.options").get()
	local border = options.strings.output_border
	text = tostring(text) or ""

	-- stylua: ignore
	local line_table = {
		success    = { { border, options.hl.output }, { options.strings.cell_executed,                         options.hl.success } },
		output     = { { border, options.hl.output }, { text,                                                  options.hl.output  } },
		error      = { { border, options.hl.error  }, { text,                                                  options.hl.error   } },
		truncation = { { border, options.hl.output }, { string.format(options.strings.truncated_output, text), options.hl.hint    } },
		image      = { { border, options.hl.output }, { string.format(options.strings.image_output, text),     options.hl.hint    } },
		running    = { { border, options.hl.output }, { options.strings.cell_running,                          options.hl.hint    } },
	}

	table.insert(tble, line_table[type])
end

--- get a string for a border the width of the terminal
--- @param label? string optional label in the border
--- @return string
function M.border_text(label)
	local options = require("notebook.options").get()

	local width = vim.api.nvim_get_option_value("columns", {})

	if label then
		local prefix = string.rep(options.strings.cell_border, 2) .. label
		local count = width - #prefix
		return prefix .. string.rep(options.strings.cell_border, count)
	else
		return string.rep(options.strings.cell_border, width)
	end
end

--- insert a border separator extmark
--- @param state Notebook.Sessions.session
--- @param line integer line number
--- @param ns integer namespace id
--- @param label? string default text label
function M.insert_separator(state, line, ns, label)
	local options = require("notebook.options").get()
	vim.api.nvim_buf_set_extmark(state.bufnr, ns, line, 0, {
		virt_text = { { M.border_text(label), options.hl.output } },
		virt_text_pos = "overlay",
	})
end

--- render a cell
--- @param state Notebook.Sessions.session
--- @param i integer
function M.render_cell(state, i)
	local options = require("notebook.options").get()
	local cell = state.parsed_cells[i]

	if not cell then
		return
	end

	local has_cell_gaps = options.cell_gap and options.cell_gap > 0

	-- show label for next cell when no gaps, otherwise dont show it
	local optional_code_label = (not has_cell_gaps) and options.strings.code_label or nil

	-- borders over """ around markdown
	if cell.type == "markdown" then
		M.insert_separator(state, cell.start_line - 1, M.border_ns, options.strings.markdown_label)
		-- no label if preceding another markdown cell
		local next_c = state.parsed_cells[i + 1]
		if next_c and next_c.type == "markdown" then
			M.insert_separator(state, cell.end_line + 1, M.border_ns)
		else
			M.insert_separator(state, cell.end_line + 1, M.border_ns, optional_code_label)
		end
	end
	-- border above code
	if cell.type == "code" then
		local next_c = state.parsed_cells[i + 1]
		if next_c and next_c.type == "code" then
			M.insert_separator(state, cell.end_line + 1, M.border_ns, optional_code_label)
		end
	end

	-- gap between cells
	if options.cell_gap and options.cell_gap > 0 then
		local gap_lines = {}

		-- gap location
		local gap_line = cell.start_line - (cell.type == "markdown" and 1 or 0)

		-- markdown with code before it adds a border under the code
		if cell.type == "markdown" then
			local next_c = state.parsed_cells[i - 1]
			if next_c and next_c.type == "code" then
				table.insert(gap_lines, { { M.border_text(), options.hl.output } })
			end
		end
		-- actual gap
		if gap_line ~= 0 then
			for _ = 1, options.cell_gap do
				table.insert(gap_lines, { { "", "" } })
			end
		end
		-- extra border above code cells
		if cell.type == "code" then
			table.insert(gap_lines, { { M.border_text(options.strings.code_label), options.hl.output } })
		end

		-- insert
		pcall(vim.api.nvim_buf_set_extmark, state.bufnr, M.border_ns, gap_line, 0, {
			virt_lines_above = true,
			virt_lines = gap_lines,
		})
	end

	-- everything else is just for code
	if cell.type ~= "code" then
		return
	end

	-- get code output
	local cell_out = state.output_store[i] or {}
	local virt_lines = {}
	local count = 0
	local img_count = 0

	-- show running if running
	if cell_out.running then
		M.insert_virtual_line(virt_lines, "running")
	end

	-- show success if it was executed
	if cell_out.executed then
		M.insert_virtual_line(virt_lines, "success")
	end

	-- cleanup existing snacks images
	if state.snacks_images[i] then
		for _, img in ipairs(state.snacks_images[i]) do
			img:close()
		end
		state.snacks_images[i] = {}
	end

	local has_snacks, snacks = pcall(require, "snacks")
	state.snacks_images[i] = state.snacks_images[i] or {}
	local snacks_images = {}
	local image_position = { cell.end_line + 1, 0 }

	-- terminal parser state for text output
	local parser = utils.create_terminal_parser(function(line)
		count = count + 1
		if count <= options.max_output_lines then
			M.insert_virtual_line(virt_lines, "output", line)
		end
	end)

	for _, out in ipairs(cell_out) do
		-- process images
		local img_data = out.data and (out.data["image/png"] or out.data["image/jpeg"])
		if img_data then
			img_count = img_count + 1

			-- flush text if an image interrupts
			parser.flush()

			if has_snacks then
				local clean_data = img_data:gsub("%s+", "")

				-- save to a temp file
				local tmp = vim.fn.tempname() .. "_" .. i .. "_" .. img_count .. ".png"

				local ok = utils.write_base64_file(clean_data, tmp)
				if ok then
					-- save image info
					table.insert(snacks_images, {
						src = tmp,
						opts = {
							pos = image_position,
							max_width = 50,
							max_height = 20,
							inline = true,
						},
					})
				end
			end
		end

		-- render text output
		local text = out.text or (out.data and out.data["text/plain"])
		if text then
			parser.push(text)
		end

		-- render errors
		if out.output_type == "error" or out.traceback then
			parser.flush() -- flush any pending text above the error

			local lines = utils.table_or_str_lines(out.traceback, true)
			for _, line in ipairs(lines) do
				local clean = utils.strip_ansi(line)
				M.insert_virtual_line(virt_lines, "error", clean)
			end
		end
	end

	-- flush remaining text
	parser.flush()

	-- truncation
	if count > options.max_output_lines then
		cell_out.is_truncated = true
		M.insert_virtual_line(virt_lines, "truncation", (count - options.max_output_lines))
	else
		cell_out.is_truncated = false
	end

	-- images virtual text
	if img_count > 0 then
		M.insert_virtual_line(virt_lines, "image", img_count)
	end

	-- add images first and in reverse to show last
	for j = #snacks_images, 1, -1 do
		local image = snacks_images[j]
		local img_obj = snacks.image.placement.new(state.bufnr, image.src, image.opts)
		table.insert(state.snacks_images[i], img_obj)
	end

	-- add border for any output or images
	if #virt_lines > 0 or #snacks_images > 0 then
		-- prepend
		table.insert(virt_lines, 1, { { M.border_text(options.strings.output_label), options.hl.output } })
	end

	-- add extmarks to buffer
	if #virt_lines > 0 then
		pcall(vim.api.nvim_buf_set_extmark, state.bufnr, M.output_ns, cell.end_line, 0, { virt_lines = virt_lines })
	end
end

return M
