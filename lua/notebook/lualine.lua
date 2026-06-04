local M = {}

function M.section()
	local bufnr = vim.api.nvim_get_current_buf()
	local sessions = require("notebook.sessions")

	if not sessions.is_session(bufnr) then
		return ""
	end

	local state = sessions.get_state(bufnr)

	local code_cells = {}
	for i, cell in ipairs(state.parsed_cells) do
		if cell.type == "code" then
			table.insert(code_cells, i)
		end
	end

	local states = {}
	for j, i in ipairs(code_cells) do
		local output = state.output_store[i] or {}
		if output.running then
			states[j] = { "DiagnosticHint", "╋" }
		elseif output.queued then
			states[j] = { "DiagnosticHint", "━" }
		elseif output.executed then
			states[j] = { "DiagnosticOk", "━" }
			for _, entry in ipairs(output) do
				if type(entry) == "table" and entry.output_type == "error" then
					states[j] = { "DiagnosticError", "━" }
				end
			end
		else
			states[j] = { "NonText", "━" }
		end
	end

	local text = ""
	for _, item in ipairs(states) do
		text = text .. "%#" .. item[1] .. "#" .. item[2]
	end

	return text
end

function M.refresh()
	vim.schedule(function()
		local ok, lualine = pcall(require, "lualine")
		if ok and lualine.refresh then
			pcall(lualine.refresh)
		end
	end)
end

return M
