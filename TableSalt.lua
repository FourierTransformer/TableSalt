#!/usr/bin/env lua
---------------
-- ## TableSalt, Lua framework for constraint satisfaction problems
--
-- It goes well with a wide variety of constraint satisfaction problems. Even ones you cook up yourself!
--
-- [Github Page](http://github.com/FourierTransformer/TableSalt)
--
--
-- @author Shakil Thakur
-- @copyright 2014
-- @license MIT
-- @script TableSalt

-- ================
-- requires and such
-- ================
local _PATH = (...):gsub('TableSalt/','') 
local class = require(_PATH .. '/util/util')
local heap = require (_PATH .. '/util/Peaque/Peaque')

-- ================
-- Private methods
-- ================
-- The following four are oddly specifc restore/backup functions. Done this way for Speed/privacy.
local function backupCells(cells)
    local serial = {{}, {}}
    for i, v in ipairs(cells) do
        serial[1][i] = {}
        for q, r in ipairs(v.domain) do
            serial[1][i][q] = r
        end
        serial[2][i] = v.value
    end
    return serial
end

local function restoreCells(cells, serial)
    for i, v in ipairs(cells) do
        v.domain = serial[1][i]
        v.value = serial[2][i]
    end
end

local function backupConstraints(constraints)
    local serial = {}
    for i, v in ipairs(constraints) do
        serial[i] = v.passed
    end
    return serial
end

local function restoreConstraints(constraints, passedArray)
    for i, v in ipairs(constraints) do
        v.passed = passedArray[i]
    end    
end

-- ================
-- Module classes
-- ================

--- `cell` class
-- @type cell
local cell = class()
function cell:initialize(id, domain)
    self.id = id
    self.domain = domain
    self.value = nil
    self.constraints = {}
end

--- `constraint` class
-- @type constraint
local constraint = class()
function constraint:initialize(section, checkFunction, ...)
    self.passed = false
    self.section = section
    self.numCells = #self.section
    self.args = ...
    self.check = function(board) return checkFunction(self.section, board, self.args) end
end

--- `TableSalt` class
-- @type TableSalt
local TableSalt = class()

--- Creates a new `TableSalt` instance. This will initialize a table, where each cell has a unique id which hold
-- a value and a domain that can be accessed through various getters, as described below.
-- @name TableSalt:new
-- @param domain the domain for each of the cells in the problem
-- @param sizeX the length of the input or a table representing the variables
-- @param sizeY (optional) - the height of the domain space if the CSP exists over a grid
-- @return a new `TableSalt` instance
-- @usage
-- local TableSalt = require('TableSalt/TableSalt')
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"}) -- for the australia coloring problem.
-- local sudoku = TableSalt:new({1,2,3,4,5,6,7,8,9}, 9, 9) -- for sudoku. Creates a 9x9 grid
-- local linear = TableSalt:new({1,2,3,4,5,6,7,8,9}, 9) -- basically creates a 9x1 grid, for problems that don't really require a grid, but can be enumerated
--
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
    self.addVarsAfterAnyChange = true
end

--- switch to toggle when additional constraints should be added for solveConstraints.
-- When this is true, it will act like the classic [AC3 algorithm](http://en.wikipedia.org/wiki/AC-3_algorithm)
-- and add constraints after any domain has changed. When it's false, it will only add contraints after a value has
-- been set (aka, the domain has been reduced to 1). If the problem is easily solved by constraints, setting this to 
-- true will incur a huge speedup (as in the case for sudoku).
-- @param bool default is `true`
-- @usage
-- local sudoku = TableSalt:new({1,2,3,4,5,6,7,8,9}, 9, 9)
-- sudoku:setAddVarsAfterAnyChange(false)
--
function TableSalt:setAddVarsAfterAnyChange(bool)
    self.addVarsAfterAnyChange = bool
end

--- returns where it's adding constraints.
-- @return `true` if after any domain change. `false` if only when a variable is assigned
--
function TableSalt:getAddVarsAfterAnyChange()
    return self.addVarsAfterAnyChange
end

--- Returns the id given a variable name
-- @param n the name of a variable used in the problem
-- @return the id associated with the given name
-- @usage
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
-- aussie:getIDByName("NSW") -- will return the ID for NSW
--
function TableSalt:getIDByName(n)
    return self.tableVals[n]
end

--- Returns the id given a pair. `(0,0)` represents the top left
-- @param x the x position from the left
-- @param y the y position from the top
-- @return the id associated with the pair
-- @usage
-- local sudoku = TableSalt:new({1,2,3,4,5,6,7,8,9}, 9, 9)
-- sudoku:getIDByPair(5,5) -- will return the id of the centermost cell
--
function TableSalt:getIDByPair(x, y)
    return (y-1)*self.sizeY+x
end

--- Returns the value given the id
-- @param i the id of the cell
-- @return the value associated with the given id or `nil` if it hasn't been set.
-- @usage
-- local linear = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 8)
-- -- various problem constraints would go here
-- linear:solve()
-- linear:getValueByID(7) -- will return the value for the 7th item
--
function TableSalt:getValueByID(i)
    return self.cells[i].value
end

--- Returns the value given a name
-- @param n the name of the variable
-- @return the value associated with the given name or `nil` if it hasn't been set.
-- @usage
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
-- -- the various australia color problem constraints would go here
-- aussie:solveForwardCheck()
-- aussie:getValueByName("WA") -- will return the value that was set for "WA" (western australia)
--
function TableSalt:getValueByName(n)
    return self:getValueByID(self:getIDByName(n))
end

--- Returns the value given a pair. `(0,0)` represents the top left
-- @param x the x position from the left
-- @param y the y position from the top
-- @return the value associated with the pair or `nil` if it hasn't been set.
-- @usage
-- local sudoku = TableSalt:new({1,2,3,4,5,6,7,8,9}, 9, 9)
-- -- the various sudoku constraints would go here
-- sudoku:solve()
-- sudoku:getValueByPair(5,5) -- will return the value of the centermost cell.
--
function TableSalt:getValueByPair(x, y)
    return self:getValueByID(self:getIDByPair(x, y))
end

--- Returns the domain given the id.
-- @param i the id
-- @return the domain (as a table) associated with the id. `{nil}` if empty
-- @usage
-- local linear = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 8)
-- -- various problem constraints would go here
-- linear:solveConstraints()
-- linear:getDomainyID(7) -- will return the domain for the 7th item. Ex: {4, 6, 8}
--
function TableSalt:getDomainByID(i)
    return self.cells[i].domain
end

--- Returns the domain given a name
-- @param n the name of the variable
-- @return the domain (as a table) associated with the given name. `{nil}` if empty
-- @usage
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
-- -- the various australia color problem constraints would go here
-- aussie:solveForwardCheck()
-- aussie:getDomainByName("WA") -- will return the domain for "WA" Ex: {"Green"}
--
function TableSalt:getDomainByName(n)
    return self:getDomainByID(self:getIDByName(n))
end

--- Returns the domain given a pair. `(0,0)` represents the top left
-- @param x the x position from the left
-- @param y the y position from the top
-- @return the domain (as a table) associated with the given pair. `{nil}` if empty
-- @usage
-- local sudoku = TableSalt:new({1,2,3,4,5,6,7,8,9}, 9, 9)
-- -- the various sudoku constraints would go here
-- sudoku:solveConstraints()
-- sudoku:getDomainByPair(5,5) -- will return the domain of the centermost cell. Ex: {1, 3, 5}
-- sudoku:solveForwardCheck()
-- sudoku:getDomainByPair(5,5) -- should be solved, so only one thing in the domain. Ex: {5}
--
function TableSalt:getDomainByPair(x, y)
    return self:getDomainByID(self:getIDByPair(x, y))
end

--- add a constraint to the board via IDs
-- @param section a table of id's
-- @param checkFunction a function which reduces domains based on a constraint
-- @param ... any additional arguments checkFunction requires
-- @usage
-- local linear = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9)
-- --id's 1, 3, and 5 have to be different
-- linear:addConstraintByIDs({1, 3, 5}, TableSalt.allDiff)
--
function TableSalt:addConstraintByIDs(section, checkFunction, ...)
    local constraintNum = #self.constraints+1
    self.constraints[ constraintNum ] = constraint:new(section, checkFunction, ...)
    for i,v in ipairs(section) do
        table.insert(self.cells[v].constraints, constraintNum)
    end
end

--- add a constraint to the board via x,y position
-- @param section a table of x,y pairs
-- @param checkFunction a function which reduces domains based on a constraint
-- @param ... any additional arguments checkFunction requires
-- @usage
-- local sudoku = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9, 9)
-- -- (1, 1), (5, 2), and (7, 2) all have a value of 4
-- sudoku:addConstraintByPairs({ {1, 1}, {5, 2}, {7, 2} }, TableSalt.setVal, 4)
--
function TableSalt:addConstraintByPairs(section, checkFunction, ...)
    local newSectionList = {}
    for i, v in ipairs(section) do
        newSectionList[i] = self:getIDByPair(v[1], v[2])
    end
    self:addConstraintByIDs(newSectionList, checkFunction, ...)
end

--- add a constraint based on the name given in the input table
-- @param section a table of names
-- @param checkFunction a function which reduces domains based on a constraint
-- @param ... any additional arguments checkFunction requires
-- @usage
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
-- aussie:addConstraintByNames({ "WA", "NT", "SA" }, TableSalt.allDiff)
--
function TableSalt:addConstraintByNames(section, checkFunction, ...)
    local newSectionList = {}
    for i, v in ipairs(section) do
        newSectionList[i] = self:getIDByName(v)
    end
    self:addConstraintByIDs(newSectionList, checkFunction, ...)
end

--- adds a constraint for each row. This is handy for grid based problems
-- @param checkFunction a function which reduces domains based on a constraint
-- @param ... any additional arguments checkFunction requires
-- @usage
-- local sudoku = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9, 9)
-- sudoku:addConstraintForEachRow(TableSalt.allDiff)
function TableSalt:addConstraintForEachRow(checkFunction, ...)
    for i = 1, self.sizeY do
        local row = {}
        for j = 1, self.sizeX do
            row[ #row+1 ] = self:getIDByPair(j, i)
        end
        self:addConstraintByIDs(row, checkFunction, ...)
    end
end

--- adds a constraint for each column. This is handy for grid based problems
-- @param checkFunction a function which reduces domains based on a constraint
-- @param ... any additional arguments checkFunction requires
-- @usage
-- local sudoku = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9, 9)
-- sudoku:addConstraintForEachColumn(TableSalt.allDiff)
function TableSalt:addConstraintForEachColumn(checkFunction, ...)
    for i = 1, self.sizeY do
        local col = {}
        for j = 1, self.sizeX do
            col[ #col+1 ] = self:getIDByPair(i, j)
        end
        self:addConstraintByIDs(col, checkFunction, ...)
    end
end

--- adds a constraint for all values
-- @param checkFunction a function which reduces domains based on a constraint
-- @param ... any additional arguments checkFunction requires
-- @usage
-- local linear = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9)
-- linear:addConstraintForAll(TableSalt.allDiff)
function TableSalt:addConstraintForAll(checkFunction, ...)
    local fullSection = {}
    for i = 1, self.size do
        fullSection[ #fullSection+1 ] = i
    end
    self:addConstraintByIDs(fullSection, checkFunction, ...)
end

--- determines if each variable has a value
-- @return `true` if each cell has a value, `false` otherwise
-- @usage
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
-- aussie:isFilled() -- should return false
--
function TableSalt:isFilled()
    for i, v in ipairs(self.cells) do
        if v.value == nil then
            return false
        end
    end
    return true
end

--- determines if the problem is solved based on the constraints that were added
-- @return `true` if all constraints are satisfied (domain has been reduced to 1 value). `false` otherwise
-- @usage
-- local aussie = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
-- --all the australia color constraints go here
-- aussie:isSolved() --should return false
-- aussie:solveForwardCheck()
-- -- isSolved should now return true as the values have been set.
-- aussie:isSolved()
function TableSalt:isSolved()
    -- it should be filled
    if not self:isFilled() then return false end

    -- run through all the constraints. Make sure they pass
    for i, v in ipairs(self.constraints) do
        local currentDomains = v.check(self)
        for q, r in ipairs(currentDomains) do
            if #r ~= 1 then
                return false
            end
        end
    end

    -- WEEEEEEEEEEEEEEEEEEEE!
    return true
    
end

function TableSalt:solveConstraints(specificConstraints)
    -- sanity checks
    if self:isSolved() then return true end

    -- init some vars
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

                -- if the domain is greater than one for any value in the section, the constraint hasn't passed
                if currentSize > 1 then
                    passedCurrentConstraint = false
                elseif currentCell.value == nil and currentSize == 1 then
                    -- however, a cell's value may be set if the length of it's list is 1
                    currentCell.value = v[1]

                    -- add affected constraints back to queue
                    if not self.addVarsAfterAnyChange then
                        for q, r in ipairs(currentCell.constraints) do
                            frontier:push(self.constraints[r])
                        end
                    end

                elseif currentSize <= 0 then
                    return nil
                end

                -- add any constraints associated with a changed domain
                if self.addVarsAfterAnyChange and oldSize ~= currentSize then
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

--- returns the id associated with the variable with the smallest domain.
-- If there's a tie, it uses the degree heuristic which picks the variable with the larger number of constraints
-- @return the id of the variable with the smallest domain
-- @usage
-- linear = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9)
-- --some of linear's constraints are added here
-- linear:solveConstraints()
-- --after that, I may want to get ahold of the domain the with smallest id
-- linear:getSmallestDomainID()
-- 
function TableSalt:getSmallestDomainID()
    local smallestDomainSize = math.huge
    local cellIndex = nil
    for i, v in ipairs(self.cells) do
        local currentDomainSize = #v.domain
        if currentDomainSize > 1 and currentDomainSize < smallestDomainSize then
            -- return cellIndex
            smallestDomainSize = currentDomainSize
            cellIndex = i
        elseif currentDomainSize == smallestDomainSize then
            -- Degree heuristic
            if #self.cells[i].constraints > #self.cells[cellIndex].constraints then
                cellIndex = i
            end
        end
    end
    return cellIndex
end

function TableSalt:solveForwardCheck()
    -- find the cell with the smallest domain
    local tinyIndex = self:getSmallestDomainID()

    -- IT EXISTS! Therefore, we can do magic.
    if tinyIndex ~= nil then
        for i,v in ipairs(self.cells[tinyIndex].domain) do
            -- copy the data (in case the constraints fail)
            local cellCopy = backupCells(self.cells)
            local constraintCopy = backupConstraints(self.constraints)

            -- set the value, then try solving the constraints
            self.cells[tinyIndex].value = v
            self.cells[tinyIndex].domain = {v}
            local wasSucessful = self:solveConstraints(self.cells[tinyIndex].constraints)

            -- stupid tail recursion...
            if wasSucessful then
                return true
            elseif wasSucessful == false then
                local extremeLevel = self:solveForwardCheck(addVarsAfterAnyChange)
                if extremeLevel then return true end
            end

            -- restore values if things go bad.
            restoreCells(self.cells, cellCopy)
            restoreConstraints(self.constraints, constraintCopy)
        end
    end
end

--- solve the constraint satisfaction problem.
-- This will call `solveConstraints` to reduce the domains and then `solveForwardCheck` to finish solving the problem
-- @return `true` if the problem was able to be solved. `false` if not.
-- @usage
-- local sudoku = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9, 9)
-- sudoku:setAddVarsAfterAnyChange(false)
-- sudoku:addConstraintForEachColumn(TableSalt.allDiff)
-- --all the other sudoku constraints go here
-- sudoku:solve()
-- sudoku:print() -- print out the problem.
function TableSalt:solve()
    local passed = self:solveConstraints()
    if not passed then
        passed = self:solveForwardCheck()
    end
    return passed
end

-- ensures all numbers in a section are of a different value
function TableSalt.allDiff(section, board)
    local valuesToRemove = {}
    local newDomains = {}
    local reverseValuesToRemove = {}

    -- determine which values have been set
    for i, v in ipairs(section) do
        local currentValue = board:getValueByID(v)
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
        local currentValue = board:getValueByID(w)
        local currentDomain = board:getDomainByID(w)
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

--- prints out the problem either as a table, a row, or a grid. How it prints out is dependent on how the inputs were given.
-- If the variables were given as a table, it will print out as a table. Otherwise it will print out as a grid. 
-- @usage
-- local sudoku = TableSalt:new({1, 2, 3, 4, 5, 6, 7, 8, 9}, 9, 9)
-- --add all the sudoku constraints here
--
-- -- will show a 9x9 grid of ?s
-- sudoku:print()
-- sudoku:solve()
-- --will show the solved sudoku puzzle now that it's solved
-- sudoku:print()
function TableSalt:print()
    if self.usingTable then
        -- I could do this, but it messes with the order of the user input. Gotta have happy users!
        -- for i in pairs(self.tableVals) do
        --     print(i, self:getValueByName(i))
        -- end
        -- and this is the only reason I stored the original user input! teehee!
        for i, v in ipairs(self.normalVals) do
            print(v, self:getValueByID(i))
        end

    else
        for j = 1, self.sizeY do
            local row = ""
            for i = 1, self.sizeX do
                local val = self:getValueByPair(i, j)
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
