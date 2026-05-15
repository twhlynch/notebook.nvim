local nb = require("notebook.notebook")

local M = {}

-- NOTE: these keys should match the keybind keys in ./options.lua

-- stylua: ignore
local descriptions = {
	run_cell           = "Run current cell",
	run_cells_all      = "Run all cells",
	run_cells_up       = "Run all cells above",
	run_cells_down     = "Run all cells below",
	run_then_next      = "Run current cell and jump to next cell",
	next_cell          = "Next cell",
	previous_cell      = "Prev cell",
	insert_markdown    = "Insert markdown cell below",
	insert_code        = "Insert code cell below",
	output_to_md       = "Convert output to markdown cell",
	output_to_md_all   = "Convert all outputs to markdown cells",
	split_cell         = "Split current cell",
	remove_cell        = "Remove current cell",
	move_cell_up       = "Move cell up",
	move_cell_down     = "Move cell down",
	clear_all_output   = "Clear all cell output",
	refresh_all_output = "Rerender output",
	open_image         = "Open current cell images",
	show_output        = "Open current cell output",
	dump_images        = "Dump all image output to /figures",
	format_cell        = "Format current cell",
	textobject_cell    = "inside cell",
	toggle_cell_type   = "Toggle cell type",
	go_to_running_cell = "Go to running cell",
}

--- @param bufnr integer
function M.setup_keymaps(bufnr)
	local state = require("notebook.sessions").get_state(bufnr)
	local options = require("notebook.options").get()

	local keymap = function(modes, leader, name, func, ...)
		local vargs = { ... }

		local key = options.keys[name]
		local desc = descriptions[name]

		vim.keymap.set(modes, (leader and options.keybind_prefix or "") .. key, function()
			func(state, unpack(vargs))
		end, { buf = bufnr, silent = true, desc = desc })
	end

	-- stylua: ignore start
	keymap({ "n" },      true,  "run_cell",           nb.run_cells, "current"    ) -- running
	keymap({ "n" },      true,  "run_cells_all",      nb.run_cells, "all"        )
	keymap({ "n" },      true,  "run_cells_up",       nb.run_cells, "up"         )
	keymap({ "n" },      true,  "run_cells_down",     nb.run_cells, "down"       )
	keymap({ "n" },      true,  "run_then_next",      nb.run_then_next           )
	keymap({ "n" },      true,  "clear_all_output",   nb.clear_output            ) -- output
	keymap({ "n" },      true,  "refresh_all_output", nb.rerender                )
	keymap({ "n" },      false, "open_image",         nb.gx_handler              ) -- viewing
	keymap({ "n" },      false, "show_output",        nb.open_output             )
	keymap({ "n" },      false, "next_cell",          nb.jump_cell, true         ) -- navigation
	keymap({ "n" },      false, "previous_cell",      nb.jump_cell, false        )
	keymap({ "o", "x" }, false, "textobject_cell",    nb.select_cell             )
	keymap({ "n" },      true,  "go_to_running_cell", nb.go_to_running_cell      )
	keymap({ "n" },      true,  "insert_markdown",    nb.insert_cell, "markdown" ) -- editing cells
	keymap({ "n" },      true,  "insert_code",        nb.insert_cell, "code"     )
	keymap({ "n" },      true,  "output_to_md",       nb.output_to_markdown      )
	keymap({ "n" },      true,  "output_to_md_all",   nb.output_to_markdown_all  )
	keymap({ "n" },      true,  "remove_cell",        nb.remove_cell             )
	keymap({ "n" },      true,  "toggle_cell_type",   nb.toggle_cell_type        )
	keymap({ "n" },      true,  "split_cell",         nb.split_cell              )
	keymap({ "n" },      true,  "move_cell_up",       nb.move_cell, "up"         )
	keymap({ "n" },      true,  "move_cell_down",     nb.move_cell, "down"       )
	keymap({ "n" },      true,  "dump_images",        nb.dump_images             ) -- utils
	keymap({ "n" },      true,  "format_cell",        nb.format_cell             )
	-- stylua: ignore end
end

return M
