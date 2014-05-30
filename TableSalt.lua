-- The game board

-- imports
local _PATH = (...):gsub('TableSalt/','') 
local util = require (_PATH .. '/util/util')
local class = util.class
local deepcopy = util.deepcopy
local heap = require (_PATH .. '/util/Peaque/Peaque')
ProFi = require 'ProFi'

-- sets the value of the cell to the actual value
local TableSalt = class()
function TableSalt.setVal(section, board, val)
    local allValues = {}
    for i = 1, #section do
        allValues [ #allValues+1 ] = {val}
    end
    return allValues
end

-- cell class
-- creates a cell with various props
local cell = class()
function cell:initialize(id, domain)
    self.id = id
    self.domain = domain
    self.domainSize = #domain
    self.value = nil
    self.constraints = {}
end

function cell:serialize()
    -- print(type(self.id))
    -- print(type(self.domain), type(self.domain[1]))
    -- print(type(self.domainSize))
    -- print(type(self.value))
    -- print(type(self.constraints), type(self.constraints[1]))
    return self.id .. ";" .. table.concat(self.domain, ",") .. ";" .. self.domainSize .. ";" .. tostring(self.value) .. ";" .. table.concat(self.constraints, ",")
end

local function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
     table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

local function splitToNum(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   cap = tonumber(cap)
   while s do
      if s ~= 1 or cap ~= "" then
     table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function cell.deserialize(str, cell)
    local deserial = split(str, ";")
    cell.id = tonumber(deserial[1])
    cell.domain = splitToNum(deserial[2], ",")
    cell.domainSize = tonumber(deserial[3])
    cell.value = tonumber(deserial[4])
    cell.constraints = splitToNum(deserial[5], ",")
end

function cell:setValue(value, board)
    self.value = value
    self.domain = {value}

    -- board:addConstraintByIDs({self.id}, TableSalt.setVal, value)
    -- return board:solveConstraints()



    for q, r in ipairs(self.constraints) do
        local currentConstraint = board.constraints[r]
        local newDomains = currentConstraint.check(board)

        for i, v in ipairs(newDomains) do
            -- gets the cell index from the constraint section list
            local cellIndex = currentConstraint.section[i]

            -- set the cell's domain to v
            board.cells[cellIndex].domain = v

            if board.cells[cellIndex].value == nil and #v == 1 then
                -- however, a cell's value may be set if the length of it's list is 1
                board.cells[cellIndex].value = v[1]

            elseif #v <= 0 then
                return nil
            end
        end
    end
    return board:isSolved()
end

local constraint = class()
function constraint:initialize(section, checkFunction, ...)
    self.passed = false
    self.section = section
    self.numCells = #self.section
    self.args = ...
    self.check = function(board) return checkFunction(self.section, board, self.args) end
end

-- TableSalt class
-- creates an nxm board of "cells"
function TableSalt:initialize(domain, sizeX, sizeY)
    -- set a "flag"
    self.usingTable = false
    if type(sizeX) == "table" then
        self.usingTable = true
    end

    -- handle input correctly
    self.tableVals = nil
    self.normalVals = nil
    if self.usingTable then
        self.sizeX = #sizeX
        self.normalVals = sizeX
        -- invert table to get id's
        self.tableVals = {}
        for i, v in ipairs(sizeX) do
            self.tableVals[v] = i
        end
    else
        self.sizeX = sizeX
    end

    self.sizeY = sizeY or 1
    self.size = self.sizeX * self.sizeY
    self.cells = {}
    for i = 1, self.size do
        self.cells[i] = cell:new(i, deepcopy(domain))
    end
    self.constraints = {}
end

function TableSalt:getCellIDByName(n)
    return self.tableVals[n]
end

function TableSalt:getCellIDByPair(x, y)
    return (y-1)*self.sizeY+x
end

function TableSalt:getCellValueByName(n)
    return self:getCellValueByID(self:getCellIDByName(n))
end

function TableSalt:getCellValueByPair(x, y)
    return self:getCellValueByID(self:getCellIDByPair(x, y))
end

function TableSalt:getCellValueByID(i)
    return self.cells[i].value
end

function TableSalt:getCellDomainByName(n)
    return self:getCellDomainByID(self:getCellIDByName(n))
end

function TableSalt:getCellDomainByPair(x, y)
    return self:getCellDomainByID(self:getCellIDByPair(x, y))
end

function TableSalt:getCellDomainByID(i)
    return self.cells[i].domain
end

function TableSalt:getCellByName(n)
    return self:getCellByID(self:getCellIDByName(n))
end

function TableSalt:getCellByPair(x, y)
    return self:getCellByID(self:getCellIDByPair(x, y))
end

function TableSalt:getCellByID(i)
    return self.cells[i]
end

-- should prolly be a toString override.

-- add a constraint to the board via IDs
-- section is a list of ids. Ex: {1, 3, 5}
function TableSalt:addConstraintByIDs(section, checkFunction, ...)
    local constraintNum = #self.constraints+1
    self.constraints[ constraintNum ] = constraint:new(section, checkFunction, ...)
    for i,v in ipairs(section) do
        table.insert(self.cells[v].constraints, constraintNum)
    end
end

-- add a constraint to the board via x,y position
-- section is a list of x,y pairs. Ex: { {1,2}, {4,6}, {7,8} }
function TableSalt:addConstraintByPairs(section, checkFunction, ...)
    local newSectionList = {}
    for i, v in ipairs(section) do
        newSectionList[i] = self:getCellIDByPair(v[1], v[2])
    end
    self:addConstraintByIDs(newSectionList, checkFunction, ...)
end

-- add a constraint based on the name given in the input table
-- section is a list of names. Ex: { "WA", "NT", "SA" }
function TableSalt:addConstraintByNames(section, checkFunction, ...)
    local newSectionList = {}
    for i, v in ipairs(section) do
        newSectionList[i] = self:getCellIDByName(v)
    end
    self:addConstraintByIDs(newSectionList, checkFunction, ...)
end

function TableSalt:addConstraintForEachRow(checkFunction, ...)
    for i = 1, self.sizeY do
        local row = {}
        for j = 1, self.sizeX do
            row[ #row+1 ] = self:getCellIDByPair(j, i)
        end
        self:addConstraintByIDs(row, checkFunction, ...)
    end
end

function TableSalt:addConstraintForEachColumn(checkFunction, ...)
    for i = 1, self.sizeY do
        local col = {}
        for j = 1, self.sizeX do
            col[ #col+1 ] = self:getCellIDByPair(i, j)
        end
        self:addConstraintByIDs(col, checkFunction, ...)
    end
end

function TableSalt:addConstraintForEntireTable(checkFunction, ...)
    local fullSection = {}
    for i = 1, self.size do
        fullSection[ #fullSection+1 ] = i
    end
    self:addConstraintByIDs(fullSection, checkFunction, ...)
end

-- ensures all numbers in a section are of a different value
function TableSalt.allDiff(section, board)
    local valuesToRemove = {}
    local newDomains = {}
    local reverseValuesToRemove = {}

    -- determine which values have been set
    for i, v in ipairs(section) do
        local currentValue = board:getCellValueByID(v)
        if currentValue ~= nil then
            if reverseValuesToRemove[currentValue] == true then
                newDomains[i] = {}
            else
                reverseValuesToRemove[currentValue] = true
                table.insert(valuesToRemove, currentValue)
                newDomains[i] = {currentValue}
            end 
        end
    end

    -- remove those values from the domain of the others
    for ind, w in ipairs(section) do
        local currentValue = board:getCellValueByID(w)
        local currentDomain = board:getCellDomainByID(w)
        if currentValue == nil then
            local indicesToRemove = {}
            for i, v in ipairs(currentDomain) do
                for j, t in ipairs(valuesToRemove) do
                    if v == t then
                        indicesToRemove[ #indicesToRemove+1 ] = i
                    end
                end
            end

            for i = #indicesToRemove, 1, -1 do
                table.remove(currentDomain, indicesToRemove[i])
            end
            newDomains[ind] = currentDomain
        end
    end

    -- return the new domains
    return newDomains
end

function TableSalt:isSolved()
    -- for i, v in ipairs(self.constraints) do
    --     local currentDomains = v.check(self)
    --     for q, r in ipairs(currentDomains) do
    --         if #r ~= 1 then
    --             return false
    --         end
    --     end
    -- end

    -- Much redundant. Very wow.
    for i, v in ipairs(self.cells) do
        if v.value == nil then
            return false
        end
    end
    return true
end

function TableSalt:solveConstraints(addVarsAfterAnyChange)
    -- sanity checks
    if self:isSolved() then return true end

    local addVarsAfterAnyChange = addVarsAfterAnyChange or false
    local frontier = heap:new()
    for i, v in ipairs(self.constraints) do
        frontier:push(v, v.numCells)
    end
    local lastVal = frontier:size()
    while not frontier:isEmpty() do
        local currentConstraint = frontier:pop()
        if not currentConstraint.passed then
            local newDomains = currentConstraint.check(self)
            local passedCurrentConstraint = true
            for i, v in ipairs(newDomains) do
                -- gets the cell index from the constraint section list
                local cellIndex = currentConstraint.section[i]

                -- old domain size used to determine what constraints should be re-added
                local oldSize = #self.cells[cellIndex].domain
                local currentSize = #v

                -- set the cell's domain to v
                self.cells[cellIndex].domain = v
                self.cells[cellIndex].domainSize = currentSize

                -- if the domain is greater than one for any value in the section, the constraint hasn't passed
                if currentSize > 1 then
                    passedCurrentConstraint = false
                elseif self.cells[cellIndex].value == nil and #v == 1 then
                    -- however, a cell's value may be set if the length of it's list is 1
                    self.cells[cellIndex].value = v[1]

                    -- add affected constraints back to queue
                    for q, r in ipairs(self.cells[cellIndex].constraints) do
                        frontier:push(self.constraints[r], lastVal)
                        lastVal = lastVal+1
                    end

                elseif currentSize <= 0 then
                    -- error("a cell's domain's size was less than 1, please check your constraints and try again")
                    return nil
                end

                -- add any constraints associated with a changed domain
                if addVarsAfterAnyChange and oldSize ~= currentSize then
                    for i, v in ipairs(currentConstraint.section) do
                        local cellIndex = currentConstraint.section[i]
                        for q, r in ipairs(self.cells[cellIndex].constraints) do
                            frontier:push(self.constraints[r], lastVal)
                            lastVal = lastVal+1
                        end
                    end
                end

            end
            -- update constraint status
            currentConstraint.passed = passedCurrentConstraint
        end
    end
    return self:isSolved()
end

function TableSalt:solveConstraints2(addVarsAfterAnyChange, cell)

    local addVarsAfterAnyChange = addVarsAfterAnyChange or false
    local frontier = heap:new()

    -- if a cell was passed in, use it's constraints.
    if cell ~= nil then
        for q, r in ipairs(cell.constraints) do
            local currentConstraint = self.constraints[r]
            frontier:push(currentConstraint, currentConstraint.numCells)
        end
    else
        for i, v in ipairs(self.constraints) do
            frontier:push(v, v.numCells)
        end
    end

    local lastVal = frontier:size()
    while not frontier:isEmpty() do
        local currentConstraint = frontier:pop()
        if not currentConstraint.passed then
            local newDomains = currentConstraint.check(self)
            local passedCurrentConstraint = true
            for i, v in ipairs(newDomains) do
                -- gets the cell index from the constraint section list
                local cellIndex = currentConstraint.section[i]
                local currentCell = self.cells[cellIndex]

                -- old domain size used to determine what constraints should be re-added
                local oldSize = #currentCell.domain
                local currentSize = #v

                -- set the cell's domain to v
                currentCell.domain = v
                currentCell.domainSize = currentSize

                -- if the domain is greater than one for any value in the section, the constraint hasn't passed
                if currentSize > 1 then
                    passedCurrentConstraint = false
                elseif currentCell.value == nil and currentSize == 1 then
                    -- however, a cell's value may be set if the length of it's list is 1
                    currentCell.value = v[1]

                    -- add affected constraints back to queue
                    for q, r in ipairs(currentCell.constraints) do
                        frontier:push(self.constraints[r], lastVal)
                        lastVal = lastVal+1
                    end

                elseif currentSize <= 0 then
                    -- error("a cell's domain's size was less than 1, please check your constraints and try again")
                    return nil
                end

            end
            -- update constraint status
            currentConstraint.passed = passedCurrentConstraint
        end
    end
    return self:isSolved()
end


function TableSalt:solveBackTrack(addVarsAfterAnyChange)
    local addVarsAfterAnyChange = addVarsAfterAnyChange or false

    -- sanity checks
    if self:isSolved() then return true end

    local smallestDomainSize = math.huge
    local cellIndex = nil
    for i = 1, self.size do
        local currentDomainSize = #self.cells[i].domain
        if currentDomainSize > 1 and currentDomainSize < smallestDomainSize then
            smallestDomainSize = currentDomainSize
            cellIndex = i
        elseif currentDomainSize == smallestDomainSize then
            -- Degree based backing
            -- if #self.cells[i].constraints > #self.cells[cellIndex].constraints then
            --     cellIndex = i
            -- end
        end
    end
    if cellIndex ~= nil then

        local cellCopy = deepcopy(self.cells)
        local constraintCopy = deepcopy(self.constraints)

        for q, v in ipairs(self.cells[cellIndex].domain) do
            -- add constraint
            self:addConstraintByIDs({cellIndex}, TableSalt.setVal, v)
            local passed = self:solveConstraints(addVarsAfterAnyChange)
            -- self.cells[cellIndex]:setValue(v)
            -- local passed = self.cells[cellIndex]:checkConstraints(self)

            -- if it passes, we're golden
            if passed == true then
                return true
            elseif passed == false then
                local newLevel = self:solveBackTrack(addVarsAfterAnyChange)
                if newLevel then return true else
                    self.cells = cellCopy
                    self.constraints = constraintCopy
                end
            else
                self.cells = cellCopy
                self.constraints = constraintCopy
            end

        end
    end
end

local function getSmallestCellIndex(board)
    local smallestDomainSize = math.huge
    local cellIndex = nil
    -- for i = 1, board.size do
    for i, v in ipairs(board.cells) do
        local currentDomainSize = v.domainSize
        if currentDomainSize > 1 and currentDomainSize < smallestDomainSize then
            -- return cellIndex
            smallestDomainSize = currentDomainSize
            cellIndex = i
        elseif currentDomainSize == smallestDomainSize then
            -- Degree based backing
            -- if #board.cells[i].constraints > #board.cells[cellIndex].constraints then
            --     cellIndex = i
            -- end
        end
    end
    return cellIndex
end

local function checkForNil(board)
    local passed = true
    local count = 0
    for i = 1, board.size do
        if board:getCellValueByID(i) == nil then
            count = count + 1
            passed = false
        end
    end
    print("Failed with", count)
    return passed
end

function TableSalt:solveBackTrack2()
    local tinyIndex = getSmallestCellIndex(self)
    local serial = self.cells[tinyIndex]:serialize()
    print(serial)
    cell.deserialize(serial, self.cells[tinyIndex])
    serial = self.cells[tinyIndex]:serialize()
    print(serial)
    print("\n")
    if tinyIndex ~= nil then
        
        for i,v in ipairs(self.cells[tinyIndex].domain) do
            local cellCopy = deepcopy(self.cells)
            local constraintCopy = deepcopy(self.constraints)
            -- local wasSucessful = self.cells[tinyIndex]:setValue(v, self)
            -- add constraint
            self:addConstraintByIDs({tinyIndex}, TableSalt.setVal, v)
            local wasSucessful = self:solveConstraints2(false, self.cells[tinyIndex])

            if wasSucessful then
                return true
            elseif wasSucessful == false then
                local extremeLevel = self:solveBackTrack2()
                if extremeLevel then return true end
            end
            self.cells = cellCopy
            self.constraints = constraintCopy
        end
    end
end

function TableSalt:solve(addVarsAfterAnyChange)
    local addVarsAfterAnyChange = addVarsAfterAnyChange or false
    local passed = self:solveConstraints(addVarsAfterAnyChange)
    if not passed then
        -- ProFi:start()
        passed = self:solveBackTrack2()
        -- ProFi:stop()
        -- ProFi:writeReport( 'backtrack2.txt' )
    end
    return passed
end

function TableSalt:print()
    if self.usingTable then
        -- I could do this, but it messes with the order of the user input. Gotta have happy users!
        -- for i in pairs(self.tableVals) do
        --     print(i, self:getCellValueByName(i))
        -- end
        -- and this is the only reason I stored the original user input! teehee!
        for i, v in ipairs(self.normalVals) do
            print(v, self:getCellValueByID(i))
        end

    else
        for j = 1, self.sizeY do
            local row = ""
            for i = 1, self.sizeX do
                local val = self:getCellValueByPair(i, j)
                if val ~= nil then
                    row = row .. val .. " "
                else
                    row = row .. "?" .. " "
                end
            end
            print(row)
        end
    end
end

return TableSalt
