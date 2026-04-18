local constants = require("notebook.constants")
local renderer = require("notebook.renderer")

local M = {}

--- handle jupyter output
--- @param state Notebook.Sessions.session
--- @param data string[] stout data
function M.stdout_callback(state, data)
	if not data then
		return
	end

	local raw_data = table.concat(data, "\n")
	state.read_buffer = state.read_buffer .. raw_data

	while true do
		local newline_pos = string.find(state.read_buffer, "\n")
		if not newline_pos then
			break
		end

		-- extract one potential JSON line
		local line = string.sub(state.read_buffer, 1, newline_pos - 1)
		state.read_buffer = string.sub(state.read_buffer, newline_pos + 1)

		if line ~= "" then
			local ok, msg = pcall(vim.json.decode, line)
			if ok and msg.cell_idx then
				local idx = msg.cell_idx
				state.output_store[idx] = state.output_store[idx] or {}

				if msg.type == "stream" then
					table.insert(state.output_store[idx], {
						output_type = "stream",
						name = "stdout",
						text = msg.content.text,
					})
				elseif msg.type == "display_data" or msg.type == "execute_result" then
					table.insert(state.output_store[idx], {
						output_type = msg.type,
						data = msg.content.data,
						metadata = vim.empty_dict(),
					})
				elseif msg.type == "error" then
					table.insert(state.output_store[idx], {
						output_type = "error",
						traceback = msg.content.traceback,
						ename = msg.content.ename,
						evalue = msg.content.evalue,
					})
				elseif msg.type == "status" and msg.content.execution_state == "idle" then
					state.output_store[idx].executed = true
					state.output_store[idx].running = false
				end
			end

			-- output counts as a file change
			vim.bo[state.bufnr].modified = true
		end
	end

	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(state.bufnr) then
			renderer.render(state)
		end
	end)
end

--- handle jupyter errors
--- @param _ Notebook.Sessions.session
--- @param data string[] stderr data
function M.stderr_callback(_, data)
	local options = require("notebook.options").get()
	if not options.debug or not data or #data == 0 or data[1] == "" then
		return
	end
	vim.schedule(function()
		vim.notify(constants.strings.bridge_error .. table.concat(data, "\n"), vim.log.levels.ERROR)
	end)
end

--- prompt installing jupyter
--- @param python string path to python executable
function M.prompt_install(python)
	local choice = vim.fn.confirm(constants.strings.install_prompt, "&No\n&Yes", 1)
	if choice ~= 2 then
		vim.notify(constants.strings.no_client, vim.log.levels.WARN)
		return
	end

	vim.notify(constants.strings.installing, vim.log.levels.INFO)
	local install_cmd = { python, "-m", "pip", "install", "jupyter_client", "ipykernel" }
	vim.fn.jobstart(install_cmd, {
		on_exit = function(_, code)
			if code == 0 then
				vim.notify(constants.strings.install_success, vim.log.levels.INFO)
			else
				vim.notify(constants.strings.install_fail, vim.log.levels.ERROR)
			end
		end,
	})
end

--- start the jupyter client
--- @param state Notebook.Sessions.session
--- @return boolean
function M.start_client(state)
	local options = require("notebook.options").get()
	-- find ideal python executable
	local cmd = "python3"
	local local_venv = vim.fn.getcwd() .. "/.venv/bin/python3"
	if vim.fn.executable(local_venv) == 1 then
		cmd = local_venv
	else
		local parent_venv = vim.fn.getcwd() .. "/../.venv/bin/python3"
		if vim.fn.executable(parent_venv) == 1 then
			cmd = parent_venv
		end
	end

	if cmd == "python3" then
		local path = vim.fn.system({ "which", cmd })
		if not (path:match("%.venv")) then
			vim.notify(constants.strings.no_venv, vim.log.levels.WARN)
		end
	end

	-- autoinstall jupyter_client
	vim.fn.system({ cmd, "-c", "import jupyter_client, ipykernel" })
	if vim.v.shell_error ~= 0 then
		M.prompt_install(cmd)
		return false
	end

	-- python bridge using jupyter_client
	local BRIDGE_PY = [[
import sys, json
from jupyter_client import KernelManager

def main():
    try:
        km = KernelManager(kernel_name='python3')
        km.start_kernel()
        kc = km.client()
        kc.start_channels()
        kc.wait_for_ready()
]] .. (options.custom_plot_theme and [[
        setup_code = """
try:
    import matplotlib.pyplot as plt
    from cycler import cycler

    plt.rcParams['axes.prop_cycle'] = cycler('color', [']] .. table.concat(options.custom_theme_colors, "', '") .. [['])

    white    = (0.9, 0.9, 0.9, 1)
    black    = (0, 0, 0, 1)
    ts       = (0, 0, 0, 0)
    ts_white = (0.9, 0.9, 0.9, 0.05)
    ts_black = (0, 0, 0, 0.1)

    plt.rcParams['lines.color'] = white
    plt.rcParams['patch.edgecolor'] = white
    plt.rcParams['text.color'] = white

    plt.rcParams['axes.facecolor'] = ts
    plt.rcParams['axes.edgecolor'] = white
    plt.rcParams['axes.labelcolor'] = white

    plt.rcParams['xtick.color'] = white
    plt.rcParams['ytick.color'] = white

    plt.rcParams['grid.color'] = white

    plt.rcParams['figure.facecolor'] = ts
    plt.rcParams['figure.edgecolor'] = black

    plt.rcParams['boxplot.boxprops.color'] = white
    plt.rcParams['boxplot.capprops.color'] = white
    plt.rcParams['boxplot.flierprops.color'] = white
    plt.rcParams['boxplot.flierprops.markeredgecolor'] = white
    plt.rcParams['boxplot.whiskerprops.color'] = white

except:
    pass
"""
        kc.execute(setup_code, silent=True)
]] or "") .. [[
        for line in sys.stdin:
            if not line.strip(): continue
            req = json.loads(line)
            cell_idx = req["cell_idx"]
            msg_id = kc.execute(req["code"])

            while True:
                msg = kc.get_iopub_msg()
                msg_type = msg['header']['msg_type']
                content = msg['content']
                parent_id = msg['parent_header'].get('msg_id')

                if parent_id == msg_id:
                    out = {"cell_idx": cell_idx, "type": msg_type, "content": content}
                    sys.stdout.write(json.dumps(out) + "\n")
                    sys.stdout.flush()

                    if msg_type == 'status' and content.get('execution_state') == 'idle':
                        break
    except Exception as e:
        sys.stderr.write(f"Bridge Error: {str(e)}\n")
        sys.stderr.flush()

if __name__ == '__main__':
    main()
]]

	-- start client executing bridge script
	local command = { cmd, "-c", BRIDGE_PY }

	-- start client
	state.job_id = vim.fn.jobstart(command, {
		on_stdout = function(_, data)
			M.stdout_callback(state, data)
		end,
		on_stderr = function(_, data)
			M.stderr_callback(state, data)
		end,
	})

	return true
end

--- run a set of cells
--- @param state Notebook.Sessions.session
--- @param indices integer[]
function M.run_cells(state, indices)
	-- start client if needed
	if not state.job_id or vim.fn.jobwait({ state.job_id }, 0)[1] ~= -1 then
		-- If start_client fails abort execution
		if not M.start_client(state) then
			return
		end
	end

	-- run required cells in order
	for _, i in ipairs(indices) do
		-- if cell is code
		if state.parsed_cells[i].type == "code" then
			-- get code lines
			local processed = {}
			for _, line in ipairs(state.parsed_cells[i].source) do
				-- uncomment magics before sending
				if line:match("^# %%") then
					table.insert(processed, (line:gsub("^# ", "")))
				else
					table.insert(processed, line)
				end
			end
			local code = table.concat(processed, "\n")

			-- execute
			if code ~= "" then
				-- reset executed state
				state.output_store[i] = {
					executed = false,
					running = true,
				}

				-- send execution request as json
				local req = vim.json.encode({ cell_idx = i, code = code })
				vim.fn.chansend(state.job_id, req .. "\n")
			end
		end
	end
end

return M
