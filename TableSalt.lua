-- The game board

-- imports
local util = require ('util/util')
local class = util.class
local deepcopy = util.deepcopy
local heap = require ('util/Peaque/Peaque')

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
function TableSalt:initialize(sizeX, sizeY, domain)
    self.sizeX = sizeX
    self.sizeY = sizeY
    self.size = sizeX*sizeY
    self.cells = {}
    for i = 1, self.size^2 do
        self.cells[i] = cell:new(i, deepcopy(domain))
    end
    self.constraints = {}
end

function TableSalt:getCellID(x, y)
    return (y-1)*self.sizeY+x
end

function TableSalt:getCellValueByPair(x, y)
    return self.cells[self:getCellID(x, y)].value
end

function TableSalt:getCellValueByID(i)
    return self.cells[i].value
end

function TableSalt:getCellByPair(x, y)
    return self.cells[self:getCellID(x, y)]
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
        newSectionList[i] = self:getCellID(v[1], v[2])
    end
    self:addConstraintByIDs(newSectionList, checkFunction, ...)
end

function TableSalt:addConstraintForEachRow(checkFunction, ...)
    for i = 1, self.sizeY do
        local row = {}
        for j = 1, self.sizeX do
            row[ #row+1 ] = self:getCellID(j, i)
        end
        self:addConstraintByIDs(row, checkFunction, ...)
    end
end

function TableSalt:addConstraintForEachColumn(checkFunction, ...)
    for i = 1, self.sizeY do
        local col = {}
        for j = 1, self.sizeX do
            col[ #col+1 ] = self:getCellID(i, j)
        end
        self:addConstraintByIDs(col, checkFunction, ...)
    end
end

function TableSalt:addConstraintForEntireTable(checkFunction, ...)
    local fullSection = {}
    for i = 1, self.size^2 do
        fullSection[ #fullSection+1 ] = i
    end
    self:addConstraintByIDs(fullSection, checkFunction, ...)
end

-- sets the value of the cell to the actual value
function TableSalt.setVal(section, board, val)
    return {{val}}
end

-- ensures all numbers in a section are of a different value
function TableSalt.allDiff(section, board)
    local valuesToRemove = {}
    local newDomains = {}

    -- determine which values have been set
    for i, v in ipairs(section) do
        local currentValue = board.cells[v].value 
        if currentValue ~= nil then
            table.insert(valuesToRemove, currentValue)
            newDomains[i] = {currentValue}
        end
    end

    -- remove those values from the domain of the others
    for ind, w in ipairs(section) do
        local currentValue = board.cells[w].value
        local currentDomain = board.cells[w].domain
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

function TableSalt:solveConstraints(addVarsAfterAnyChange)
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

                -- -- add any constraints associated with a changed domain
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
    local passed = true
    for _, cons in ipairs(self.constraints) do
        if cons.passed == false then
            passed = false
        end
    end
    return passed
end

function TableSalt:solveBackTrack(addVarsAfterAnyChange)
    local addVarsAfterAnyChange = addVarsAfterAnyChange or true
    local smallestDomainSize = math.huge
    local cellIndex = nil
    for i = 1, self.size do
        local currentDomainSize = #self.cells[i].domain
        if currentDomainSize > 1 and currentDomainSize < smallestDomainSize then
            smallestDomainSize = currentDomainSize
            cellIndex = i
        end
    end
    if cellIndex ~= nil then
        -- make a copy of the old cells
        for w, x in ipairs(self.constraints) do
            x.passed = false
        end
        local oldboard = deepcopy(self)

        for q, v in ipairs(self.cells[cellIndex].domain) do
            -- clear old constraints and add one of the values to the constraints            
            self:addConstraintByIDs({cellIndex}, TableSalt.setVal, v)

            -- run it and handle the cases correctly
            local didItPass = self:solveConstraints(addVarsAfterAnyChange)
            
            if didItPass then
                return true
            elseif didItPass == false then
                -- Maybe we just need to iterate deeper?
                local herp = self:solveBackTrack()
                if herp == true then
                    return herp
                end
            end
            -- remove the constraint that was just added and try again
            self = oldboard
        end
    end
    return false
end

function TableSalt:solve(addVarsAfterAnyChange)
    local addVarsAfterAnyChange = addVarsAfterAnyChange or true
    local passed = self:solveConstraints(addVarsAfterAnyChange)
    if not passed then
        passed = self:solveBackTrack(addVarsAfterAnyChange)
    end
    return passed
end

function TableSalt:printTable()
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

return TableSalt
