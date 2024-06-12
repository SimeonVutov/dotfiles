-- Function to focus previous buffer
local function focus_previous_buffer()
    if previous_buffer ~= nil then
        vim.api.nvim_set_current_buf(previous_buffer) -- Set focus to previous buffer
    else
        print("No previous buffer found")
    end
end

