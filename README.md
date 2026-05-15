# notebook.nvim

Edit and run Python Jupyter Notebooks as single buffers.

Unlike conventional notebook interfaces, this plugin renders all cells in a single buffer, allowing you to edit and run
cells without having to 'open' cells. The approach is to dump everything into a single python file and use docstring
comments to represent markdown cells.
Cover that in a bunch of extmarks and you get a unique way of using Python Jupyter Notebooks.

<img src="meta/banner.png" width="400" />

Example usage for `lazy.nvim`.

```lua
return {
	"twhlynch/notebook.nvim"
	opts = {
		keybind_prefix = "<leader>c",
	},
}
```

<details><summary>Default Options and Keybinds</summary>

```lua
return {
	"twhlynch/notebook.nvim",
	opts = {
		keybind_prefix = "<leader>c",
		max_output_lines = 10,
		custom_plot_theme = true,
		custom_theme_colors = { '#4878CF', '#6ACC65', '#D65F5F', '#B47CC7', '#C4AD66', '#77BEDB' },
		cell_gap = 0,
		write_output = true,
		new_cell_cmd = "normal! A\nstartinsert!",
		format_command = "black --quiet -",
		image_warn_threshold = 10,
		override_gitsigns = true,
		override_conform = true,
		show_elapsed_time = true,
		elapsed_timer_interval = 1000,

		keys = {
			run_cell           = "r",
			run_cells_all      = "a",
			run_cells_up       = "u",
			run_cells_down     = "d",
			run_then_next      = "<CR>",

			next_cell          = "]c",
			previous_cell      = "[c",
			textobject_cell    = "ic",

			insert_markdown    = "m",
			insert_code        = "c",
			output_to_md       = "im",
			output_to_md_all   = "ia",
			split_cell         = "s",
			remove_cell        = "X",
			move_cell_up       = "<up>",
			move_cell_down     = "<down>",

			clear_all_output   = "x",
			refresh_all_output = "R",
			format_cell        = "f",
			toggle_cell_type   = "S",
			go_to_running_cell = "g",

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

			output_border  = "┃   ",
			cell_border    = "─",
			code_label     = " λ code ",
			markdown_label = " ¶ markdown ",
			output_label   = " ⇒ output ",

			cell_executed    = "[ ✓ Done ]",
			cell_running     = "[ Running... ]",
			cell_pending     = "[ Pending... ]",
			truncated_output = "<Enter> %s more lines",
			image_output     = "<gx> %s × image",
		},
	},
}
```

</details>

<details><summary>Formatting</summary>

By default `black` formatter fails on notebooks due to them not matching their actual files.
This can be fixed by using black through stdin instead of letting it find the file istelf.
Example with `conform`:

```lua
conform.setup({
	formatters = {
		black = {
			command = "black",
			args = { "--quiet", "-" },
			stdin = true,
		},
	},
})
```

</details>

<details><summary>Lualine setup</summary>

Add the notebook status section to your lualine config:

```lua
require("lualine").setup({
	sections = {
		lualine_x = {
			"notebook",
		},
	},
})
```

</details>
