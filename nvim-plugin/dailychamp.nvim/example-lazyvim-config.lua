-- Example LazyVim plugin configuration
-- Place this file in: ~/.config/nvim/lua/plugins/dailychamp.lua

return {
  dir = "~/code/deliverists.io/dailychamp_app/nvim-plugin/dailychamp.nvim",
  ft = "markdown",
  config = function()
    require("dailychamp").setup({
      -- Customize your settings here
      file_path = vim.fn.expand("~/Nextcloud/Notes/dailychamp/daily.md"),
      leader = "<leader>d",
      default_hours = "1.0",
      sections = {
        "Goals",
        "Tasks",
        "Notes",
        "Reflections"
      },
    })
  end,
}
