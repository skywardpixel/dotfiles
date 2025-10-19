return {
    {
        "yetone/avante.nvim",
        build = "make",
        version = false,
        event = "VeryLazy",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
        },
        opts = {},
    },
}
