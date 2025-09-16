-- themes.lua — definición de estilos HUD
local themes = {
  minimalist = {
    bg = colors.black,
    fg = colors.white,
    accent = colors.orange,
  },
  retro = {
    bg = colors.black,
    fg = colors.green,
    accent = colors.lime,
  },
  neon = {
    bg = colors.black,
    fg = colors.cyan,
    accent = colors.magenta,
  },
  compact = {
    bg = colors.gray,
    fg = colors.white,
    accent = colors.blue,
  },
  ascii = {
    bg = colors.black,
    fg = colors.white,
    accent = colors.lightGray,
  },
  hologram = {
    bg = colors.black,
    fg = colors.cyan,
    accent = colors.purple,
  },
  -- 🚀 aquí puedes añadir más temas personalizados
  -- draconic = {
  --   bg = colors.black,
  --   fg = colors.orange,
  --   accent = colors.red,
  -- },
}

return themes
