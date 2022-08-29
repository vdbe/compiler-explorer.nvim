local config = require("compiler-explorer.config")

local api, fn = vim.api, vim.fn

local M = {}

local function create_linehl_dict(asm)
  local source_to_asm, asm_to_source = {}, {}
  for asm_idx, line_obj in ipairs(asm) do
    if line_obj.source ~= vim.NIL then
      if line_obj.source.line ~= vim.NIL then
        local source_idx = line_obj.source.line
        if source_to_asm[source_idx] == nil then
          source_to_asm[source_idx] = {}
        end

        table.insert(source_to_asm[source_idx], asm_idx)
        asm_to_source[asm_idx] = source_idx
      end
    end
  end

  return source_to_asm, asm_to_source
end

M.create_autocmd = function(source_bufnr, asm_bufnr, resp)
  local conf = config.get_config()
  local source_to_asm, asm_to_source = create_linehl_dict(resp)

  local gid = api.nvim_create_augroup("CompilerExplorer", { clear = true })
  local ns = api.nvim_create_namespace("CompilerExplorer")
  local ns2 = api.nvim_create_namespace("Comp")

  api.nvim_create_autocmd({ "CursorMoved" }, {
    group = gid,
    buffer = source_bufnr,
    callback = function()
      -- clear previous highlights
      api.nvim_buf_clear_namespace(asm_bufnr, ns, 0, -1)

      local line_nr = fn.line(".")
      local hl_ranges = source_to_asm[line_nr]
      if hl_ranges == nil then
        return
      end

      for _, hl in ipairs(hl_ranges) do
        vim.highlight.range(asm_bufnr, ns, conf.autocmd.hl, { hl - 1, 0 }, { hl - 1, -1 }, "linewise", true)
      end
    end,
  })

  api.nvim_create_autocmd({ "BufLeave" }, {
    group = gid,
    buffer = source_bufnr,
    callback = function()
      api.nvim_buf_clear_namespace(asm_bufnr, ns, 0, -1)
    end,
  })

  api.nvim_create_autocmd({ "CursorMoved" }, {
    group = gid,
    buffer = asm_bufnr,
    callback = function()
      -- clear previous highlights
      api.nvim_buf_clear_namespace(source_bufnr, ns2, 0, -1)

      local line_nr = fn.line(".")
      local hl_ranges = asm_to_source[line_nr]
      if hl_ranges == nil then
        return
      end

      vim.highlight.range(
        source_bufnr,
        ns2,
        conf.autocmd.hl,
        { hl_ranges - 1, 0 },
        { hl_ranges - 1, -1 },
        "linewise",
        true
      )
    end,
  })

  api.nvim_create_autocmd({ "BufLeave" }, {
    group = gid,
    buffer = asm_bufnr,
    callback = function()
      api.nvim_buf_clear_namespace(source_bufnr, ns2, 0, -1)
    end,
  })
end

return M
