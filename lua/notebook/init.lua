local M = {}

--- plugin setup
--- @param options Notebook.Options.options option overrides
function M.setup(options)
	-- set options
	require("notebook.options").set(options)

	-- setup rest of plugin
	require("notebook.renderer").setup()
	require("notebook.notebook").setup()
end

return M
