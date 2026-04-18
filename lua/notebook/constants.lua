--- @class Notebook.Constants constants module
--- @field strings table<string, string>

--- @type Notebook.Constants
local M = {
	-- stylua: ignore
	strings = {
		-- notifications

		bridge_error    = "Jupyter Bridge Error: ",
		install_prompt  = "Missing 'jupyter_client'. Install with pip?",
		no_client       = "Not running client",
		installing      = "Installing jupyter_client...",
		install_success = "Successfully installed",
		install_fail    = "Failed to install",
		no_venv         = "Not using a virtual environment",
		saved_images    = "Saved %d images",
		images_prompt   = "Dump images to working directory?",
		images_warning  = "Are you sure you want to open %d images?",

		-- keybind descriptions
		-- NOTE: these keys should match the keybind keys in ./options.lua

		run_cell_desc           = "Run current cell",
		run_cells_all_desc      = "Run all cells",
		run_cells_up_desc       = "Run all cells above",
		run_cells_down_desc     = "Run all cells below",
		next_cell_desc          = "Next cell",
		previous_cell_desc      = "Prev cell",
		insert_markdown_desc    = "Insert markdown cell below",
		insert_code_desc        = "Insert code cell below",
		split_cell_desc         = "Split current cell",
		remove_cell_desc        = "Remove current cell",
		clear_all_output_desc   = "Clear all cell output",
		refresh_all_output_desc = "Rerender output",
		open_image_desc         = "Open current cell images",
		show_output_desc        = "Open current cell output",
		dump_images_desc        = "Dump all image output to /figures",
	},
}

return M
