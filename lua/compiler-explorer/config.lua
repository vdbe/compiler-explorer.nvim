local M = {}

M.defaults = {
  url = "https://godbolt.org",
  prompt = {
    lang = "Select language> ",
    compiler = "Select compiler> ",
    compiler_opts = "Select compiler options> ",
    formatter = "Select formatter> ",
    formatter_style = "Select formatter style> ",
  },
  format_item = {
    lang = function(item)
      return item.name -- Other possible fields: extensions, id, monaco
    end,
    compiler = function(item)
      return item.name -- Other possible fields: compilerType, id, instructionSet, lang, semver
    end,
    formatter = function(item)
      return item.name -- Other possible fields: exe, styles, type, version
    end,
    formatter_style = function(item)
      return item
    end,
  },
}

M._config = M.defaults

function M.setup(user_config)
  M._config = vim.tbl_deep_extend("force", M._config, user_config)
end

function M.get_config()
  return M._config
end
return M