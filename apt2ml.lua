#!/usr/bin/luajit

local files = {}

-- Source - https://stackoverflow.com/a/27028488
-- Posted by hookenz, modified by community. See post 'Timeline' for change history
-- Retrieved 2026-10-28, License - CC BY-SA 4.0

local function apturl_to_file(line)
    local file = {
        url=string.match(line, "'(.+)' ")
    }

    if file.url == nil then
        return nil
    end

    line = string.sub(line, string.len(file["url"]) + 4)

    local value_index = 1
    local FIELDS = {
        "name", "size"
    }

    for value in string.gmatch(line, "([^ ]+) ") do
        local fieldname = FIELDS[value_index]
        if fieldname ~= nil then
            -- name, size
            file[fieldname] = value
        elseif value_index == 3 then
            -- hash field
            local colon_pos = string.find(value, ":", nil, true)
            if colon_pos ~= nil then
                local hashtype = string.sub(value, 1, colon_pos)
                if hashtype == "MD5Sum" then
                    FIELDS.hash = {}
                    FIELDS.hash[1] = string.sub(value, colon_pos)
                    FIELDS.hash.type = "md5"
                end
            end
        end
        value_index = value_index + 1
    end

    return file
end

local function serialize_file(file)
    local el =
        '  <file name="' .. file.name .. '">\n' ..
        '    <url>' .. file.url .. '</url>\n'
    if file.size ~= nil then
        el = el ..
            '    <size>' .. file.size .. '</size>\n'
    end
    if file.hash ~= nil then
        el = el ..
            '    <hash type="' .. file.hash.type .. '">'
            .. file.hash[1]
            .. '</hash>\n'
    end
    return el ..
        '  </file>\n'
end

function output_meta4()
    local document =
        '<?xml version="1.0" encoding="UTF-8"?>\n' ..
        '<metalink xmlns="urn:ietf:params:xml:ns:metalink">\n'
    for line in io.stdin:lines() do
        local f = apturl_to_file(line)
        if f ~= nil then
            document = document ..
                serialize_file(f)
        end
    end
    document = document ..
        '</metalink>\n'
    print(document)
end

output_meta4()