--- @class Notebook.Options options module
--- @field options Notebook.Options.options the options
--- @field set function setter with deep extend
--- @field get function getter

--- @type Notebook.Options
local M = {}

--- @class Notebook.Options.options plugin options
--- main / top level options
--- @field keybind_prefix string prefix for all basic keybinds
--- @field max_output_lines integer maximum lines of output to display before truncating
--- @field custom_plot_theme boolean whether to use a custom theme for matplotlib
--- @field custom_theme_colors string[] list of hex colors to use for matplotlib cycler
--- @field cell_gap integer number of blank virtual lines to place in between cells
--- @field write_output boolean set to false to prevent cell output from being written to the file
--- @field new_cell_cmd string an Ex cmd to run after creating a new cell
--- @field image_warn_threshold integer how many images will cause opening them to require confirmation
--- @field debug boolean debug mode for development
--- categorised option sections
--- @field keys Notebook.Options.options.keys keybinds
--- @field hl Notebook.Options.options.highlights highlight groups
--- @field strings Notebook.Options.options.strings strings

--- @class Notebook.Options.options.keys plugin keybind related options
--- running cells
--- @field run_cell string keybind to run the current cell
--- @field run_cells_all string keybind to run all cells
--- @field run_cells_up string keybind to run all cells above and the current cell
--- @field run_cells_down string keybind to run the current cell and all cells below
--- jumping
--- @field next_cell string keybind to jump to the next cell
--- @field previous_cell string keybind to jump to the previous cell
--- @field textobject_cell string textobject keybind for 'inside cell'
--- adding cells
--- @field insert_markdown string keybind to insert a markdown cell under the current cell
--- @field insert_code string keybind to insert a code cell under the current cell
--- @field split_cell string keybind to split the current cell at the cursor
--- @field remove_cell string keybind to remove the current cell
--- other
--- @field clear_all_output string keybind to clear all output data
--- @field refresh_all_output string keybind to rerender in the case of all too common rendering bugs
--- @field open_image string keybind to open the current cells images in the systems image viewer
--- @field show_output string keybind to show the full output in a floating window
--- @field dump_images string keybind to save all images 'dump' into a `/figures` directory

--- @class Notebook.Options.options.highlights plugin highlight group options
--- @field output string highlight group for output
--- @field error string highlight group for error output
--- @field hint string highlight group for hints (such as output truncation or image count)
--- @field success string highlight group for cell run success text

--- @class Notebook.Options.options.strings all plugin strings exposed to be customised
--- new cell content
--- @field new_cell string[] list of strings to insert into new markdown cells
--- @field new_code_cell string[] list of strings to insert into new code cells
--- structure and state info
--- @field output_border string string to use as the border left of cell output
--- @field cell_border string character used for cell borders
--- @field cell_executed string string to show when a cell finishes running
--- @field cell_running string string to show when a cell is running
--- @field truncated_output string string to show when output is truncated %s for line count
--- @field image_output string string to show when output has images %s for image count

-- stylua: ignore
--- @type Notebook.Options.options
M.options = {
	keybind_prefix = "<leader>c",
	max_output_lines = 10,
	custom_plot_theme = true,
	custom_theme_colors = { '#4878CF', '#6ACC65', '#D65F5F', '#B47CC7', '#C4AD66', '#77BEDB' },
	cell_gap = 0,
	write_output = true,
	new_cell_cmd = "normal! A\nstartinsert!",
	image_warn_threshold = 10,
	debug = false,

	keys = {
		run_cell           = "r",
		run_cells_all      = "a",
		run_cells_up       = "u",
		run_cells_down     = "d",

		next_cell          = "]c",
		previous_cell      = "[c",
		textobject_cell    = "ic",

		insert_markdown    = "m",
		insert_code        = "c",
		split_cell         = "s",
		remove_cell        = "X",

		clear_all_output   = "x",
		refresh_all_output = "R",

		open_image         = "gx",
		show_output        = "<CR>",
		dump_images        = "D",
	},

	hl = {
		output  = "NonText",
		error   = "DiagnosticError",
		hint    = "DiagnosticHint",
		success = "DiagnosticOk",
	},

	strings = {
		new_cell      = { "# " },
		new_code_cell = { "# " },

		output_border    = "┃   ",
		cell_border      = "─",
		cell_executed    = "[ ✓ Done ]",
		cell_running     = "[ Running... ]",
		truncated_output = "<Enter> %s more lines",
		image_output     = "<gx> %s × image",
	},
}

--- sets plugin options keeping defaults if unspecified
--- @param opts? Notebook.Options.options new options to override defaults
function M.set(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

--- get current options
--- @return Notebook.Options.options
function M.get()
	return M.options
end

return M
