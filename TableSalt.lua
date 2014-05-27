-- The game board

-- imports
local _PATH = (...):gsub('TableSalt/','') 
local util = require (_PATH .. '/util/util')
local class = util.class
local deepcopy = util.deepcopy
local heap = require (_PATH .. '/util/Peaque/Peaque')

-- cell class
-- creates a cell with various props
local cell = class()
function cell:initialize(id, domain)
    self.id = id
    self.domain = domain
    self.value = nil
    self.constraints = {}
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
local TableSalt = class()
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

-- sets the value of the cell to the actual value
function TableSalt.setVal(section, board, val)
    local allValues = {}
    for i = 1, #section do
        allValues [ #allValues+1 ] = {val}
    end
    return allValues
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
    for i, v in ipairs(self.constraints) do
        local currentDomains = v.check(self)
        for q, r in ipairs(currentDomains) do
            if #r ~= 1 then
                return false
            end
        end
    end

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

                -- set the cell's domain to v
                self.cells[cellIndex].domain = v

                -- if the domain is greater than one for any value in the section, the constraint hasn't passed
                if #v > 1 then
                    passedCurrentConstraint = false
                elseif self.cells[cellIndex].value == nil and #v == 1 then
                    -- however, a cell's value may be set if the length of it's list is 1
                    self.cells[cellIndex].value = v[1]

                    -- add affected constraints back to queue
                    for q, r in ipairs(self.cells[cellIndex].constraints) do
                        frontier:push(self.constraints[r], lastVal)
                        lastVal = lastVal+1
                    end

                elseif #v <= 0 then
                    -- error("a cell's domain's size was less than 1, please check your constraints and try again")
                    return nil
                end

                -- add any constraints associated with a changed domain
                if addVarsAfterAnyChange and oldSize ~= #v then
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
            if #self.cells[i].constraints > #self.cells[cellIndex].constraints then
                cellIndex = i
            end
        end
    end
    if cellIndex ~= nil then

        local cellCopy = deepcopy(self.cells)
        local constraintCopy = deepcopy(self.constraints)

        for q, v in ipairs(self.cells[cellIndex].domain) do
            -- add constraint
            self:addConstraintByIDs({cellIndex}, TableSalt.setVal, v)
            local passed = self:solveConstraints(addVarsAfterAnyChange)

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

function TableSalt:solve(addVarsAfterAnyChange)
    local addVarsAfterAnyChange = addVarsAfterAnyChange or false
    local passed = self:solveConstraints(addVarsAfterAnyChange)
    -- local passed = false
    if not passed then
        passed = self:solveBackTrack()
    end
    return passed
end

function TableSalt:print()
    if self.usingTable then
        -- I could do this, but it messes with the order that the user inputted...
        -- for i in pairs(self.tableVals) do
        --     print(i, self:getCellValueByName(i))
        -- end
        -- So, I'll just store a copy of what they inputted and use that!
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
