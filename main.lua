local binser = require "binser"
local utf8 = require "utf8"

local path
local deserializedFile
local dropdowns = {}
local tableEditRef = {}
local keyEditRef
local typeRef
local keyStringInput
local valueStringInput
local editField
local keyResultType
local valueResultType
local contextMenuX
local contextMenuY
local contextMenuEnabled

local isEditing = false

local screenXOffset = 0
local screenYOffset = 0
local function recursivelyIncludeDropdowns(table, dropdown, recursion_lv)
    dropdown.__open__ = false
    local dashes = ""
    for i = 1, recursion_lv do
        dashes = dashes.."- "
    end
    -- print(dashes, "dropdown initialized", recursion_lv, dropdown, dropdown.value)
    for key, value in next, table do
        if type(key) == "table" then
            dropdowns[key] = {}
            -- print(dashes, "dropdown created at key", recursion_lv)
            recursivelyIncludeDropdowns(key, dropdowns[key], recursion_lv + 1)
        end
        if type(value) == "table" then
            dropdowns[value] = {}
            -- print(dashes, "dropdown created at value", recursion_lv)
            recursivelyIncludeDropdowns(value, dropdowns[value], recursion_lv + 1)
        end
    end
end
function love.textinput(t)
    if isEditing then
        if editField == "key" then
            keyStringInput = keyStringInput .. t
        end
        if editField == "value" then
            valueStringInput = valueStringInput .. t
        end
    end
end

function love.keypressed(key, scancode)
    if scancode == "escape" then
        isEditing = false
    end
    if scancode == "return" then
        isEditing = false
        if keyEditRef ~= nil and valueResultType ~= "table" then
            tableEditRef[keyEditRef] = nil
        end
        
        if keyResultType == "boolean" then
            if keyStringInput == "true" then
                keyStringInput = true
            else
                keyStringInput = false
            end
        elseif keyResultType == "number" then
            keyStringInput = tonumber(keyStringInput)
        elseif valueResultType == "string" then
            keyStringInput = tostring(keyStringInput)
        elseif keyResultType == "table" then
            keyStringInput = type(keyStringInput) == "table" and keyStringInput or {}
        end
        if keyStringInput ~= nil then
            if valueResultType == "boolean" then
                if valueStringInput == "true" then
                    tableEditRef[keyStringInput] = true
                else
                    tableEditRef[keyStringInput] = false
                end
            elseif valueResultType == "number" then
                tableEditRef[keyStringInput] = tonumber(valueStringInput)
            elseif valueResultType == "string" then
                tableEditRef[keyStringInput] = tostring(valueStringInput)
            elseif valueResultType == "table" then
                tableEditRef[keyStringInput] = type(tableEditRef[keyStringInput]) == "table" and tableEditRef[keyStringInput] or {}
            end
        end
    end
    if scancode == "backspace" and isEditing then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(editField == "key" and keyStringInput or editField == "value" and valueStringInput, -1)

        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            if editField == "key" and type(keyStringInput) == "string" then
                keyStringInput = string.sub(keyStringInput, 1, byteoffset - 1)
            end
            if editField == "value" and type(valueStringInput) == "string" then
                valueStringInput = string.sub(valueStringInput, 1, byteoffset - 1)
            end
        end
    end
end
---@return any
function deepcopy(t)
    -- returns infinite-layer deep copy of t
	if type(t) ~= "table" then return t end
	local target = {}
	for k, v in next, t do
		target[deepcopy(k)] = deepcopy(v)
	end
	setmetatable(target, deepcopy(getmetatable(t)))
	return target
end

---@param file love.File
function love.filedropped(file)
    path = file:getFilename()
    file:open("r")
    local strData = file:read("string")
    deserializedFile = deepcopy(binser.d(strData))
    recursivelyIncludeDropdowns(deserializedFile, dropdowns, 0)
    dropdowns.__open__ = true
    screenXOffset = 0
    screenYOffset = 0
end

local interactX = 0
local interactY = 0
local function recursivelyInteractWithTable(table, dropdown, button, recursion_lv)
    -- print(dropdown, recursion_lv, interactX, interactY)
    if not recursion_lv then
        recursion_lv = 0
    end
    if dropdown and interactX > 0 and interactY > 0 and interactY < 20 and interactX < 320 and button == 1 then
        dropdown.__open__ = not dropdown.__open__
        return true
    end
    if not (dropdown and dropdown.__open__) then
        return false
    end
    for key, value in next, table do
        if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
            interactY = interactY - 20
            if interactX > 20 and interactY > 0 and interactY < 20 and interactX < 340 and button == 2 then
                -- isEditing = true
                contextMenuEnabled = true
                contextMenuX, contextMenuY = love.mouse.getPosition()
                tableEditRef = table
                keyEditRef = key
                keyResultType = type(key)
                valueResultType = type(value)
                keyStringInput = tostring(key)
                valueStringInput = tostring(value)
            end
        end
        if type(key) == "table" then
            interactX = interactX - 20
            interactY = interactY - 20
            if button == 2 and interactX > 0 and interactY > 0 and interactY < 20 and interactX < 320 then
                contextMenuEnabled = true
                contextMenuX, contextMenuY = love.mouse.getPosition()
                tableEditRef = table
                keyEditRef = key
                keyResultType = "table"
                valueResultType = type(value)
                keyStringInput = "{ }"
                valueStringInput = value
                interactX = interactX + 20
                return true
            elseif recursivelyInteractWithTable(key, dropdowns[key], button, recursion_lv + 1) == true then
                interactX = interactX + 20
                return true
            end
            interactX = interactX + 20
        end
        if type(value) == "table" then
            interactX = interactX - 20
            interactY = interactY - 20
            if button == 2 and interactX > 0 and interactY > 0 and interactY < 20 and interactX < 320 then
                contextMenuEnabled = true
                contextMenuX, contextMenuY = love.mouse.getPosition()
                tableEditRef = table
                keyEditRef = key
                keyResultType = type(key)
                valueResultType = "table"
                keyStringInput = key
                valueStringInput = "{ }"
                interactX = interactX + 20
                return true
            elseif recursivelyInteractWithTable(value, dropdowns[value], button, recursion_lv + 1) == true then
                interactX = interactX + 20
                return true
            end
            interactX = interactX + 20
        end
    end
end

local typeSelectorInteractionTable = {
    ["key"]={
        {570, 235, 690, 255, "table"},
        {720, 235, 840, 255, "number"},
        {870, 235, 990, 255, "string"},
        {1020, 235, 1140, 255, "boolean"},
    },
    ["value"]={
        {570, 455, 690, 475, "table"},
        {720, 455, 840, 475, "number"},
        {870, 455, 990, 475, "string"},
        {1020, 455, 1140, 475, "boolean"},
    },
}

---@param x number
---@param y number
---@param button integer
---@param istouch boolean
---@param presses integer
function love.mousepressed(x, y, button, istouch, presses)
    if deserializedFile == nil then
        return
    end
    if contextMenuEnabled then
        contextMenuEnabled = false
        if x > contextMenuX and y > contextMenuY and x < contextMenuX + 150 and y < contextMenuY + 60 then
            if y < contextMenuY + 20 then
                keyStringInput = ""
                valueStringInput = ""
            end
            if y < contextMenuY + 40 then
                isEditing = true
                keyEditRef = y > contextMenuY + 20 and keyEditRef or nil
            else
                tableEditRef[keyEditRef] = nil
            end
        end
    end
    if isEditing then
        for i = 1, 4 do
            local k = typeSelectorInteractionTable.key[i]
            local v = typeSelectorInteractionTable.value[i]
            if x > k[1] and y > k[2] and x < k[3] and y < k[4] then
                keyResultType = k[5]
                print("pressed k", k[5])
            end
            if x > v[1] and y > v[2] and x < v[3] and y < v[4] then
                valueResultType = v[5]
                print("pressed v", v[5])
            end
        end
        if x > 420 and y > 285 and x < 1380 and y < 305 then
            editField = "key"
        elseif x > 420 and y > 505 and x < 1380 and y < 525 then
            editField = "value"
        else
            editField = "none"
        end
    end
    if x < 40 and y < 20 then
        saveData(path)
    end
    interactX = x - screenXOffset
    interactY = y - screenYOffset
    recursivelyInteractWithTable(deserializedFile, dropdowns, button, 0)
end
local cursor_type
function setSystemCursorType(cursor)
    cursor_type = cursor
end
function CursorHighlight(x,y,w,h)
	local mouse_x, mouse_y = love.mouse.getPosition()
    mouse_x, mouse_y = mouse_x - screenXOffset, mouse_y - screenYOffset
	if mouse_x > x and mouse_x < x+w and mouse_y > y and mouse_y < y+h then
		setSystemCursorType("hand")
		return 0
	else
		return 1
	end
end
function love.update()
    
end
function saveData(filepath)
    local file = io.open(path, "w")
    binser.writeFile(filepath, unpack(deserializedFile))
end
local renderXOffset = 0
local renderYOffset = 0
local function stringTypeQuote(string)
    if type(string) == "string" then
        return ("\"%s\""):format(tostring(string))
    else
        return tostring(string)
    end
end
local function recursivelyDrawTable(table, dropdown, name)
    local gray = 0.5 / (CursorHighlight(renderXOffset, renderYOffset, 320, 20) + 1)
    love.graphics.setColor(gray, gray, gray, 1)
    love.graphics.rectangle("fill", renderXOffset, renderYOffset, 320, 20)
    love.graphics.setColor(1, 1, 1, 1)
    if dropdown and dropdown.__open__ == true then
        love.graphics.printf((name or tostring(table))..", Left-click to close ^", 10 + renderXOffset, renderYOffset, 300, "center")
    elseif dropdown and dropdown.__open__ == false then
        love.graphics.printf((name or tostring(table))..", Left-click to open V", 10 + renderXOffset, renderYOffset, 300, "center")
        return
    else
        love.graphics.printf((name or tostring(table))..", faulty", 10 + renderXOffset, renderYOffset, 300, "center")
        return
    end
    for key, value in next, table do
        if type(key) == "table" then
            renderXOffset = renderXOffset + 20
            renderYOffset = renderYOffset + 20
            recursivelyDrawTable(key, dropdowns[key], "table-key")
            renderXOffset = renderXOffset - 20
        end
        if type(value) == "table" then
            renderXOffset = renderXOffset + 20
            renderYOffset = renderYOffset + 20
            recursivelyDrawTable(value, dropdowns[value], key)
            renderXOffset = renderXOffset - 20
        end
        if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
            renderYOffset = renderYOffset + 20
            local width = love.graphics.getFont():getWidth(stringTypeQuote(key).." : "..stringTypeQuote(value))
            gray = 0.5 / (CursorHighlight(renderXOffset + 20, renderYOffset, width, 20) + 1)
            love.graphics.setColor(gray, gray, gray, 1)
            love.graphics.rectangle("fill", renderXOffset + 20, renderYOffset, width + 10, 20)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(stringTypeQuote(key).." : "..stringTypeQuote(value), 5 + renderXOffset + 20, renderYOffset, width)
        end
    end
end
function love.wheelmoved(x, y)
    screenXOffset = screenXOffset - x * 100
    screenYOffset = screenYOffset + y * 100
end
local typeSelectorTable = {
    {570, 235, 120, 20, "Table", "table"},
    {720, 235, 120, 20, "Number", "number"},
    {870, 235, 120, 20, "String", "string"},
    {1020, 235, 120, 20, "Boolean", "boolean"},
    {570, 455, 120, 20, "Table", "table"},
    {720, 455, 120, 20, "Number", "number"},
    {870, 455, 120, 20, "String", "string"},
    {1020, 455, 120, 20, "Boolean", "boolean"},
}
function love.draw()
    setSystemCursorType("arrow")
    renderXOffset = 0
    renderYOffset = 0
    if deserializedFile ~= nil then
        love.graphics.translate(screenXOffset, screenYOffset)
        recursivelyDrawTable(deserializedFile, dropdowns, "root")
        love.graphics.origin()
        local gray = 0.5 / (CursorHighlight(-screenXOffset, -screenYOffset, 40, 20) + 1)
        love.graphics.setColor(gray, gray, gray, 1)
        love.graphics.rectangle("fill", 0, 0, 40, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Save", 0, 0, 40, "center")
    else
        love.graphics.print("Please drop down a file!", 120, 80, 0, 4, 4)
    end
    if contextMenuEnabled then
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.rectangle("fill", contextMenuX, contextMenuY, 150, 60)
        love.graphics.setColor(1, 1, CursorHighlight(contextMenuX, contextMenuY, 150, 20), 1)
        love.graphics.print("Add key value pair", contextMenuX, contextMenuY)
        love.graphics.setColor(1, 1, CursorHighlight(contextMenuX, contextMenuY + 20, 150, 20), 1)
        love.graphics.print("Edit key value pair", contextMenuX, contextMenuY + 20)
        love.graphics.setColor(1, 1, CursorHighlight(contextMenuX, contextMenuY + 40, 150, 20), 1)
        love.graphics.print("Delete key value pair", contextMenuX, contextMenuY + 40)
        love.graphics.setColor(1, 1, 1, 1)
    end
    if isEditing then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.rectangle("fill", 400, 225, 800, 450)
        love.graphics.setColor(0.25, 0.25, 0.25, 1)
        love.graphics.rectangle("fill", 420, 285, 760, 20)
        love.graphics.rectangle("fill", 420, 505, 760, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Type:", 420, 235)
        love.graphics.print("Type:", 420, 455)
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        for index, value in ipairs(typeSelectorTable) do
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.rectangle("fill", value[1], value[2], value[3], value[4])
            -- print(index, (index <= #typeSelectorTable and keyResultType or valueResultType) == value[6])
            local highlight = (index <= #typeSelectorTable / 2 and keyResultType or valueResultType) == value[6] and 0 or CursorHighlight(value[1], value[2], value[3], value[4])
            love.graphics.setColor(1, 1, highlight, 1)
            love.graphics.printf(value[5], value[1], value[2], value[3], "center")
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Key:", 420, 265)
        love.graphics.print("Value:", 420, 485)
        if keyResultType ~= "table" then
            love.graphics.print(keyStringInput..(editField == "key" and "|" or ""), 420, 285)
        else
            love.graphics.print("{ }", 420, 285)
        end 
        if valueResultType ~= "table" then
            love.graphics.print(valueStringInput..(editField == "value" and "|" or ""), 420, 505)
        else
            love.graphics.print("{ }", 420, 505)
        end 
    end
    love.mouse.setCursor(love.mouse.getSystemCursor(cursor_type))
end