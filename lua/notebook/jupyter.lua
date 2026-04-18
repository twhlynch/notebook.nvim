--- Jupyter structure implementation

--- @class Notebook.Jupyter.Notebook
--- @field cells Notebook.Jupyter.Cell
--- @field metadata Notebook.Jupyter.Metadata
--- @field nbformat integer
--- @field nbformat_minor integer

--- @alias Notebook.Jupyter.CellType "markdown" | "code"

--- @class Notebook.Jupyter.Cell
--- @field cell_type Notebook.Jupyter.CellType
--- @field execution_count integer | vim.NIL
--- @field id string
--- @field metadata Notebook.Jupyter.CellMetadata
--- @field outputs Notebook.Jupyter.Output[]
--- @field source string[]

--- @alias Notebook.Jupyter.Output Notebook.Jupyter.Output.stream | Notebook.Jupyter.Output.error | Notebook.Jupyter.Output.display_data | Notebook.Jupyter.Output.execute_result

--- @class Notebook.Jupyter.Output.stream
--- @field output_type "stream"
--- @field name "stdout" | "stderr"
--- @field text string[]

--- @class Notebook.Jupyter.Output.error
--- @field ename string
--- @field evalue string
--- @field traceback string[]

--- @class Notebook.Jupyter.Output.display_data
--- @field output_type "display_data"
--- @field execution_count integer
--- @field data Notebook.Jupyter.DisplayData
--- @field metadata table

--- @class Notebook.Jupyter.Output.execute_result
--- @field output_type "execute_result"
--- @field data Notebook.Jupyter.DisplayData
--- @field metadata table

--- @class Notebook.Jupyter.DisplayData
--- @field ['text/plain']? string
--- @field ['image/png']? string
--- @field ['image/jpeg']? string

--- @alias Notebook.Jupyter.CellMetadata table currently not used by plugin

--- @class Notebook.Jupyter.Metadata
--- @field kernelspec Notebook.Jupyter.KernelSpec
--- @field language_info Notebook.Jupyter.LanguageInfo

--- @class Notebook.Jupyter.KernelSpec
--- @field display_name string
--- @field language string
--- @field name string

--- @class Notebook.Jupyter.LanguageInfo
--- @field name string
--- @field version? string

local M = {}

--- get a blank notebook template
--- @return Notebook.Jupyter.Notebook
function M.blank_notebook()
	return {
		cells = {},
		metadata = {
			kernelspec = {
				display_name = ".venv",
				language = "python",
				name = "python3",
			},
			language_info = {
				name = "python",
			},
		},
		nbformat = 4,
		nbformat_minor = 5,
	}
end

return M
