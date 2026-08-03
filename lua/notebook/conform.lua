local M = {}

function M.conform_after_format()
	local conform_ok, conform = pcall(require, "conform")
	if not conform_ok then
		return
	end

	local format = conform.format
	if not format then
		return
	end

	conform.format = function(opts, ...)
		format(opts, ...)

		-- only active notebook sessions
		local bufnr = (opts or {}).bufnr or vim.api.nvim_get_current_buf()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		local sessions = require("notebook.sessions")
		if not sessions.is_session(bufnr) then
			return
		end
		local state = sessions.get_state(bufnr)

		-- reparse, resync, rerender
		local notebook = require("notebook.notebook")
		notebook.parse_buffer(state)
		local cells = state.parsed_cells
		notebook.sync_buffer(state, cells)
		notebook.rerender(state)
	end
end

function M.setup()
	local options = require("notebook.options").get()
	if options.override_conform then
		M.conform_after_format()
	end
end

return M
