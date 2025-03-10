local M = {}

M.setup = function()

end

local state = {
  floating = {
    buf = -1,
    win = -1
  }
}


function create_floating_window(config, enter)

  if enter == nil then
    enter = false
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter, config)

  return { buf = buf, win = win }
end

local create_window_configuration = function()
  local width = vim.o.columns
  local height = vim.o.lines
  local header_height = 1 + 2
  local footer_height = 1
  local body_height = height - header_height - footer_height - 2-- 2 for our own border

  ---@type vim.api.keyset.win_config
  local windows = {
    background = {
      relative = "editor",
      width = width,
      height = height,
      style = "minimal",
      border = "none",
      col = 0,
      row = 0,
      zindex = 1
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      col = 0,
      row = 0,
      border = "rounded",
      zindex = 2
    },
    body = {
      relative = "editor",
      width = width - 6,
      height = body_height,
      style = "minimal",
      col = 8,
      row = 7,
      border = "none",
    },
    footer = {
      relative = "editor",
      width = width,
      height = footer_height,
      style = "minimal",
      col = 0,
      row = height - 3,
      zindex = 2
    }
  }
  return windows
end

---@class present.Slides
---@field slides present.Slide[]: the slides of the file

---@class present.Slide
---@field title string
---@field body string[]

--- takes some lines and parse them
---@param lines string[]
---@return present.Slides: The lines in the buffer
local parse_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {
    title = "",
    body = {}
  }
  local separator = "^#"
  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end
      current_slide = {
        title = line,
        body = {}
      }
    else
      table.insert(current_slide.body, line)
    end
  end
  table.insert(slides.slides, current_slide)
  return slides
end

local state = {
  parsed = {},
  current_slide = 1,
  floats = {
    background = {},
    header = {},
    body = {}
  }
}

local foreach_float = function(cb)
  for name, float in pairs(state.floats) do
    cb(name, float)
  end
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.buf = opts.buf or 0
  local lines = vim.api.nvim_buf_get_lines(opts.buf, 0, -1, false)
  state.parsed = parse_slides(lines)
  state.current_slide = 1


  local windows = create_window_configuration()

  state.floats.background = create_floating_window(windows.background)
  state.floats.header = create_floating_window(windows.header)
  state.floats.footer = create_floating_window(windows.footer)
  state.floats.body = create_floating_window(windows.body, true)


  foreach_float(function (_, float)
    vim.bo[float.buf].filetype = "markdown"
  end)

  local set_slide_content = function(idx)
    local width = vim.o.columns
    local slide = state.parsed.slides[idx]

    local padding = string.rep(" ", (width - #slide.title) / 2)
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, {title})
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
    local footer_text = string.format("%d/%d", state.current_slide, #state.parsed.slides)
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, {footer_text})
  end

  vim.keymap.set('n', 'n', function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
    set_slide_content(state.current_slide)
  end, {
    buffer = state.floats.body.buf
  })
  vim.keymap.set('n', 'p', function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end, {
    buffer = state.floats.body.buf
  })
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(state.floats.body.win, true)
  end, {
    buffer = state.floats.body.buf
  })

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0
    }
  }

  for option, config in pairs(restore) do
    vim.opt[option] = config.present
  end

  local restore_group = vim.api.nvim_create_augroup('restore-buf', { clear = true })
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = state.floats.body.buf,
    group = restore_group,
    callback = function()
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end
      vim.api.nvim_win_close(state.floats.header.win, true)
      vim.api.nvim_win_close(state.floats.background.win, true)
      vim.api.nvim_win_close(state.floats.footer.win, true)
    end
  })

  local resize_group = vim.api.nvim_create_augroup("resize_group", { clear = true })
  vim.api.nvim_create_autocmd('VimResized', {
    buffer = state.floats.body.buf,
    group = resize_group,
    callback = function ()
      if vim.api.nvim_win_is_valid(state.floats.body.win) and state.floats.body.win ~= nil then
        local updated = create_window_configuration()
        foreach_float(function (name, float)
          vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
        end)
        set_slide_content(state.current_slide)
      end
    end
  })
  set_slide_content(state.current_slide)
end

M._parse_slides = parse_slides

return M
