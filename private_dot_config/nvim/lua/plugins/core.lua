return {
    { "folke/which-key.nvim", event = "VeryLazy", opts = {} },

    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<C-p>",     "<cmd>Telescope find_files<cr>", desc = "Find Files" },
            { "<leader>/", "<cmd>Telescope live_grep<cr>",  desc = "Live Grep" },
        },
    },

    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        keys = {
            { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Explorer" },
        },
    },
}
