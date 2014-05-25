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

-- board class
-- creates an nxn board of "cells"
local board = class()
function board:initialize(sizeX, sizeY, domain)
    self.sizeX = sizeX
    self.sizeY = sizeY
    self.size = sizeX*sizeY
    self.cells = {}
    for i = 1, self.size^2 do
        self.cells[i] = cell:new(i, deepcopy(domain))
    end
    self.sections = {}
    self.constraints = {}
end

function board:getCellID(x, y)
    return (y-1)*self.sizeY+x
end

function board:getCellValueByPair(x, y)
    return self.cells[self:getCellID(x, y)].value
end

function board:getCellValueByID(i)
    return self.cells[i].value
end

function board:getCellByPair(x, y)
    return self.cells[self:getCellID(x, y)]
end

function board:getCellByID(i)
    return self.cells[i]
end

-- should prolly be a toString override.

-- add a constraint to the board via IDs
-- section is a list of ids. Ex: {1, 3, 5}
function board:addConstraintIDs(section, checkFunction, ...)
    local constraintNum = #self.constraints+1
    self.constraints[ constraintNum ] = constraint:new(section, checkFunction, ...)
    for i,v in ipairs(section) do
        table.insert(self.cells[v].constraints, constraintNum)
    end
end

-- add a constraint to the board via x,y position
-- section is a list of x,y pairs. Ex: { {1,2}, {4,6}, {7,8} }
function board:addConstraintPairs(section, checkFunction, ...)
    local newSectionList = {}
    for i, v in ipairs(section) do
        newSectionList[i] = self:getCellID(v[1], v[2])
    end
    self:addConstraintIDs(newSectionList, checkFunction, ...)
end

function board:addConstraintForEachRow(checkFunction, ...)
    for i = 1, self.sizeY do
        local row = {}
        for j = 1, self.sizeX do
            row[ #row+1 ] = self:getCellID(j, i)
        end
        self:addConstraintIDs(row, checkFunction, ...)
    end
end

function board:addConstraintForEachColumn(checkFunction, ...)
    for i = 1, self.sizeY do
        local col = {}
        for j = 1, self.sizeX do
            col[ #col+1 ] = self:getCellID(i, j)
        end
        self:addConstraintIDs(col, checkFunction, ...)
    end
end

function board:addConstraintForEntireTable(checkFunction, ...)
    local fullSection = {}
    for i = 1, self.size^2 do
        fullSection[ #fullSection+1 ] = i
    end
    self:addConstraintIDs(fullSection, checkFunction, ...)
end

-- sets the value of the cell to the actual value
function board.setVal(section, board, val)
    return {{val}}
end

-- ensures all numbers in a section are of a different value
function board.allDiff(section, board)
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

function board:printTable()
    for j = 1, 9 do
        local row = ""
        for i = 1, 9 do
            local val = self:getCellValueByPair(i, j)
            if val ~= nil then
                row = row .. val .. " "
            else
                row = row .. "?" .. " "
            end
            if i%3 == 0 then
                row = row .. "|" .. " "
            end
        end
        print(row)
        if j % 3 == 0 then
            print("- - - - - - - - - - - -")
        end
    end
end

function board:SolveConstraints(addAnyVarOnChange)
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
                if addAnyVarOnChange and oldSize ~= #v then
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

function board.solveDFS(boardly)
    -- now that domain reduction is done, DFS can be applied.
    -- aka HAX
    local smallestDomainSize = math.huge
    local cellIndex = nil
    for i = 1, boardly.size do
        local currentDomainSize = #boardly.cells[i].domain
        if currentDomainSize > 1 and currentDomainSize < smallestDomainSize then
            smallestDomainSize = currentDomainSize
            cellIndex = i
        end
    end
    if cellIndex ~= nil then
        -- make a copy of the old cells
        for w, x in ipairs(boardly.constraints) do
            x.passed = false
        end
        local oldboard = deepcopy(boardly)

        for q, v in ipairs(boardly.cells[cellIndex].domain) do
            -- clear old constraints and add one of the values to the constraints            
            boardly:addConstraintIDs({cellIndex}, board.setVal, v)

            -- run it and handle the cases correctly
            local didItPass = boardly:SolveConstraints(false)
            
            if didItPass then
                return boardly, true
            elseif didItPass == false then
                -- Maybe we just need to iterate deeper?
                local boardly, herp = board.solveDFS(boardly)
                if herp == true then
                    return boardly, herp
                end
            end
            -- remove the constraint that was just added and try again
            boardly = oldboard
        end
    end
    return boardly, false
end

local function solveSudoku(puzzle)
    -- setup the board
    local test = board:new(9, 9, {1,2,3,4,5,6,7,8,9})

    -- import the puzzle to csp style
    local start_time = os.clock()
    local index = 1
    for c in puzzle:gmatch"." do
        if c ~= "0" then
            test:addConstraintIDs({index}, board.setVal, tonumber(c))
        end
        index = index + 1
    end
    local duration = (os.clock() - start_time) * 1000
    -- print(duration .. "ms to load puzzle")

    -- add the various constraints needed to solve
    for n = 0, 2 do
        for k = 0, 2 do
            local giantList = {}
            for i = 1, 3 do
                for j = 1, 3 do
                    giantList[ #giantList+1 ] = {i+k*3, j+n*3}
                end
            end
            test:addConstraintPairs(giantList, board.allDiff)
        end
    end

    -- SWEET LATIN SQUARES
    test:addConstraintForEachColumn(board.allDiff)
    test:addConstraintForEachRow(board.allDiff)

    -- solve the puzzle
    local passed = nil
    local start_time = os.clock()
    passed = test:SolveConstraints(false)
    if passed == false then
        test, passed = board.solveDFS(test)
    end
    local duration = (os.clock() - start_time) * 1000
    print(duration .. "ms to solve this puzzle")

    test:printTable()

    -- print out the solution    
    print("Able to solve?: ", passed)

    -- Debug Output (for when testing single puzzles)
    -- for j = 1, 9 do
    --     for i = 1, 9 do
    --         local cell = test:getCellByPair(i, j)
    --         if cell.value == nil then
    --             print(test:getCellID(i, j), table.concat(cell.domain))
    --         end
    --     end
    -- end

    print("\n\n")

    return passed, duration

end

-- ATTEMPT loading up the 50 puzzles from sudoku.txt
io.input("sudoku.txt")
-- Grid XX + newLine + 9 lines of (9 chars + 1 newline)
local puzzles = {}
for i = 1, 50 do
    local t = io.read(string.len("Grid XX") + 1)
    t = io.read(9*10)
    t = t:gsub("%s+", "")
    puzzles[i] = t
end

-- solveSudoku(puzzles[40])

local numPassed = 0
local totalDuration = 0
local smallestDuration = math.huge
local longestDuration = -math.huge
for i = 1, 50 do
    local passed, duration = solveSudoku(puzzles[i])
    if passed then
        numPassed = numPassed + 1
        totalDuration = totalDuration + duration
        if duration < smallestDuration then
            smallestDuration = duration
        elseif duration > longestDuration then
            longestDuration = duration
        end
    end
end

print("Passed " .. numPassed .."/50 = " .. numPassed/50*100 .. "%")
print("Total Time: " .. totalDuration .. "ms Average Time: " .. totalDuration/50 .. "ms")
print("Longest Duration: " .. longestDuration .. "ms Smallest Duration:" .. smallestDuration .. "ms")