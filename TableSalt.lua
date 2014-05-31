-- The game board

-- imports
local _PATH = (...):gsub('TableSalt/','') 
local class = require (_PATH .. '/util/util')
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

function cell:setValue(value, board)
    self.value = value
    self.domain = {value}
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
local TableSalt = class()
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
        local newDomain = {}
        for j = 1, #domain do
            newDomain[j] = domain[j]
        end
        self.cells[i] = cell:new(i, newDomain)
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

-- sets the value of the cell to the actual value
function TableSalt.setVal(section, board, val)
    local allValues = {}
    for i = 1, #section do
        allValues [ #allValues+1 ] = {val}
    end
    return allValues
end

function TableSalt:isFilled()
    for i, v in ipairs(self.cells) do
        if v.value == nil then
            return false
        end
    end
    return true
end

function TableSalt:isSolved()

    if not self:isFilled() then return false end

    for i, v in ipairs(self.constraints) do
        local currentDomains = v.check(self)
        for q, r in ipairs(currentDomains) do
            if #r ~= 1 then
                return false
            end
        end
    end

    return true
    
end

function TableSalt:solveConstraints(addVarsAfterAnyChange, specificConstraints)
    -- sanity checks
    if self:isFilled() then return true end

    -- init some vars
    local addVarsAfterAnyChange = addVarsAfterAnyChange or false
    local frontier = heap:new()

    -- if specific constraints were passed in, use those. Otherwise use EVERYTHING.
    if specificConstraints ~= nil then
        for q, r in ipairs(specificConstraints) do
            local currentConstraint = self.constraints[r]
            frontier:push(currentConstraint, currentConstraint.numCells)
        end
    else
        for i, v in ipairs(self.constraints) do
            frontier:push(v, v.numCells)
        end
    end

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

                -- if the domain is greater than one for any value in the section, the constraint hasn't passed
                if currentSize > 1 then
                    passedCurrentConstraint = false
                elseif currentCell.value == nil and currentSize == 1 then
                    -- however, a cell's value may be set if the length of it's list is 1
                    currentCell.value = v[1]

                    -- add affected constraints back to queue
                    for q, r in ipairs(currentCell.constraints) do
                        frontier:push(self.constraints[r])
                    end

                elseif currentSize <= 0 then
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

    -- this is a little ballsy. It should really be self:isSolved(), but this is done for SPEED
    return self:isFilled()
end

function TableSalt:getSmallestCellIndex(degreeCheck)
    local smallestDomainSize = math.huge
    local cellIndex = nil
    for i, v in ipairs(self.cells) do
        local currentDomainSize = #v.domain
        if currentDomainSize > 1 and currentDomainSize < smallestDomainSize then
            -- return cellIndex
            smallestDomainSize = currentDomainSize
            cellIndex = i
        elseif degreeCheck and currentDomainSize == smallestDomainSize then
            -- Degree based back track
            if #self.cells[i].constraints > #self.cells[cellIndex].constraints then
                cellIndex = i
            end
        end
    end
    return cellIndex
end

function TableSalt:backupCells()
    local serial = {{}, {}}
    for i, v in ipairs(self.cells) do
        serial[1][i] = {}
        for q, r in ipairs(v.domain) do
            serial[1][i][q] = r
        end
        serial[2][i] = v.value
    end
    return serial
end

function TableSalt:restoreCells(serial)
    for i, v in ipairs(self.cells) do
        v.domain = serial[1][i]
        v.value = serial[2][i]
    end
end

function TableSalt:backupConstraints()
    local serial = {}
    for i, v in ipairs(self.constraints) do
        serial[i] = v.passed
    end
    return serial
end

function TableSalt:restoreConstraints(passedArray)
    for i, v in ipairs(self.constraints) do
        v.passed = passedArray[i]
    end    
end

function TableSalt:solveBackTrack(degreeCheck, addVarsAfterAnyChange)
    -- find the cell with the smallest domain
    local tinyIndex = self:getSmallestCellIndex(degreeCheck)

    -- IT EXISTS! Therefore, we can do magic.
    if tinyIndex ~= nil then
        for i,v in ipairs(self.cells[tinyIndex].domain) do
            -- copy the data (in case the constraints fail)
            local domains, values = self:backupCells()
            local constraintCopy = self:backupConstraints()

            -- set the value, then try solving the constraints
            self.cells[tinyIndex]:setValue(v)
            local wasSucessful = self:solveConstraints(addVarsAfterAnyChange, self.cells[tinyIndex].constraints)

            -- stupid tail recursion...
            if wasSucessful then
                return true
            elseif wasSucessful == false then
                local extremeLevel = self:solveBackTrack(addVarsAfterAnyChange)
                if extremeLevel then return true end
            end

            -- restore values if things go bad.
            self:restoreCells(domains, values)
            self:restoreConstraints(constraintCopy)
        end
    end
end

function TableSalt:solve(degreeCheck, addVarsAfterAnyChange)
    local addVarsAfterAnyChange = addVarsAfterAnyChange or false
    local degreeCheck = degreeCheck or false
    local passed = self:solveConstraints(addVarsAfterAnyChange)
    if not passed then
        passed = self:solveBackTrack(degreeCheck, addVarsAfterAnyChange)
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
