local async = require("compiler-explorer.async")
local autocmd = require("compiler-explorer.autocmd")
local config = require("compiler-explorer.config")
local rest = require("compiler-explorer.rest")
local stderr = require("compiler-explorer.stderr")

local api, fn, cmd = vim.api, vim.fn, vim.cmd

local M = {}

local vim_select = async.wrap(vim.ui.select, 3)
local vim_input = async.wrap(vim.ui.input, 2)

M.setup = function(user_config)
  config.setup(user_config or {})
end

M.show_tooltip = function()
  local doc = rest.tooltip_get(vim.b.arch, fn.expand("<cword>"))
  vim.lsp.util.open_floating_preview({ doc.tooltip }, "markdown", {
    wrap = true,
    close_events = { "CursorMoved" },
    border = "single",
  })
end

M.compile = async.void(function(start, finish)
  local conf = config.get_config()

  local last_line = fn.line("$")
  local is_full_buffer = function(first, last)
    return (first == 1) and (last == last_line)
  end

  -- Get buffer number of the source code buffer.
  local source_bufnr = fn.bufnr("%")

  -- Get contents of the selected lines.
  local buf_contents = api.nvim_buf_get_lines(source_bufnr, start - 1, finish, false)
  local source = table.concat(buf_contents, "\n")

  local lang_list = rest.languages_get()
  local possible_langs = lang_list

  -- Do not infer language when compiling only a visual selection.
  if is_full_buffer(start, finish) then
    -- Infer language based on extension and prompt user.
    local extension = "." .. fn.expand("%:e")

    possible_langs = vim.tbl_filter(function(el)
      return vim.tbl_contains(el.extensions, extension)
    end, lang_list)

    if vim.tbl_isempty(possible_langs) then
      vim.notify(("File type %s not supported by compiler-explorer"):format(extension), vim.log.levels.ERROR)
      return
    end
  end

  -- Choose language
  local lang = vim_select(possible_langs, {
    prompt = conf.prompt.lang,
    format_item = conf.format_item.lang,
  })

  -- Choose compiler
  local compilers = rest.compilers_get(lang.id)
  local compiler = vim_select(compilers, {
    prompt = conf.prompt.compiler,
    format_item = conf.format_item.compiler,
  })

  -- Choose compiler options
  local compiler_opts = vim_input({ prompt = conf.prompt.compiler_opts })

  -- Compile
  local body = rest.create_compile_body(compiler.id, compiler_opts, source)
  local out = rest.compile_post(compiler.id, body)
  local asm_lines = {}
  for _, line in ipairs(out.asm) do
    table.insert(asm_lines, line.text)
  end

  local name = "asm"
  local asm_bufnr = fn.bufnr(name)
  if asm_bufnr == -1 then
    asm_bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(asm_bufnr, name)
    api.nvim_buf_set_option(asm_bufnr, "ft", "asm")
  end

  if fn.bufwinnr(asm_bufnr) == -1 then
    cmd("vsplit")
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, asm_bufnr)
  end

  api.nvim_buf_set_lines(asm_bufnr, 0, -1, false, asm_lines)
  async.scheduler()
  vim.notify(string.format("Compilation done %s", compiler.name))

  vim.b[asm_bufnr].arch = compiler.instructionSet
  if conf.autocmd.enable and is_full_buffer(start, finish) then
    autocmd.create_autocmd(source_bufnr, asm_bufnr, out.asm)
  end

  stderr.parse_errors(out.stderr, source_bufnr)
end)

M.format = async.void(function()
  local conf = config.get_config()

  -- Get contents of current buffer
  local buf_contents = api.nvim_buf_get_lines(0, 0, -1, false)
  local source = table.concat(buf_contents, "\n")

  -- Select formatter
  local formatters = rest.formatters_get()
  local formatter = vim_select(formatters, {
    prompt = conf.prompt.formatter,
    format_item = conf.format_item.formatter,
  })

  local style = formatter.styles[1] or "__DefaultStyle"
  if #formatter.styles > 0 then
    style = vim_select(formatter.styles, {
      prompt = conf.prompt.formatter_style,
      format_item = conf.format_item.formatter_style,
    })
  end

  local body = rest.create_format_body(formatter.type, source, style)
  local out = rest.format_post(formatter.type, body)

  -- Split by newlines
  local lines = vim.split(out.answer, "\n")

  -- Replace lines of the current buffer with formatted text
  api.nvim_buf_set_lines(0, 0, -1, false, lines)

  -- TODO: Find how to make the text appear at the proper time.
  vim.notify(("Text formatted using %s and style %s"):format(formatter.name, style))
end)

return M
