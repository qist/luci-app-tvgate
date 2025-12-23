-- yaml.lua (简化版 YAML 解析，仅支持简单 key: value)
local yaml = {}

function yaml.parse(content)
    local t = {}
    local current_section = nil
    
    for line in content:gmatch("[^\r\n]+") do
        -- 忽略注释和空行
        local clean_line = line:gsub("#.*$", "")
        if clean_line:match("^%s*[a-zA-Z_][%w_]*:%s*$") then
            -- 匹配 section，如 "web:" 或 "monitor:"
            local section_name = clean_line:match("^%s*([a-zA-Z_][%w_]*)%s*:%s*$")
            if section_name then
                current_section = section_name
                t[current_section] = t[current_section] or {}
            end
        elseif current_section and clean_line:match("%S") then
            -- 在 section 内匹配 key: value 对
            local key, value = clean_line:match("^%s*([a-zA-Z_][%w_]*)%s*:%s*([^\n\r#]*)")
            if key and value then
                -- 去除值两端的空白并处理引号
                value = value:gsub("^%s+", ""):gsub("%s+$", "")
                if value:match('^"(.*)"$') or value:match("^'(.*)'$") then
                    value = value:sub(2, -2)  -- 去除引号
                end
                t[current_section][key] = value
            end
        end
    end
    
    return t
end

return yaml