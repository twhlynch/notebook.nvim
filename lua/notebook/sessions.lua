--- @class Notebook.Sessions
--- @field sessions table<integer, Notebook.Sessions.session>

local M = {}

--- @class Notebook.Sessions.session
--- @field bufnr integer buffer id of notebook
--- @field path string | nil .ipynb file path
--- @field raw_json Notebook.Jupyter.Notebook raw notebook data
--- @field job_id integer | nil client job id
--- @field parsed_cells Notebook.Sessions.Cell[] parsed cell data
--- @field output_store Notebook.Sessions.Output[] cell output data
--- @field snacks_images table<integer, snacks.image.Placement> image instances
--- @field read_buffer string buffer for reading chunked bridge output

--- @alias Notebook.Sessions.Output Notebook.Jupyter.Output | Notebook.Sessions.Output.extras

--- @class Notebook.Sessions.Output.extras
--- @field executed boolean
--- @field running boolean
--- @field is_truncated boolean

--- @class Notebook.Sessions.Cell
--- @field type Notebook.Jupyter.CellType
--- @field source string[]
--- @field start_line integer
--- @field end_line integer

M.sessions = {}

--- get state for a session or create it for a new session
--- @param bufnr integer
--- @return Notebook.Sessions.session
function M.get_state(bufnr)
	if not M.sessions[bufnr] then
		--- @type Notebook.Sessions.session
		M.sessions[bufnr] = {
			bufnr = bufnr,
			path = nil,
			raw_json = { cells = {} },
			job_id = nil,
			parsed_cells = {},
			output_store = {},
			snacks_images = {},
			read_buffer = "",
		}
	end

	return M.sessions[bufnr]
end

return M
