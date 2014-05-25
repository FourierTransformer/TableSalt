#!/usr/bin/env lua
---------------
-- ## Peaque, Lua module for a priority queue
-- @author Shakil Thakur
-- @copyright 2014
-- @license MIT
-- @script peaque
local class = require ('class')

-- get the parent's index
local function parent(i)
    return math.floor(i/2)
end

-- get the left child's index
local function left(i)
    return 2*i
end

-- get the right child's index
local function right(i)
    return 2*i+1
end

-- swap two nodes
local function swap(A, x, y)
    local temp = A[x]
    A[x] = A[y]
    A[y] = temp
end

local function maxHeapify(A, i)
    local l = left(i)
    local r = right(i)
    local largest
    
    if l <= #A and A[l].key > A[i].key then
        largest = l
    else
        largest = i
    end

    if r <= #A and A[r].key > A[largest].key then
        largest = r
    end

    if largest ~= i then
        swap(A, i, largest)
        maxHeapify(A, largest)
    end
end

local function minHeapify(A, i)
    local l = left(i)
    local r = right(i)
    local smallest
    
    if l <= #A and A[l].key < A[i].key then
        smallest = l
    else
        smallest = i
    end

    if r <= #A and A[r].key < A[smallest].key then
        smallest = r
    end

    if smallest ~= i then
        swap(A, i, smallest)
        minHeapify(A, smallest)
    end
end

local function heapIncrease(A, i, key)
    assert(A[i].key < key, "new key should be smaller than current")
    A[i].key = key
    while i > 1 and A[parent(i)].key < A[i].key do
        swap(A, i, parent(i))
        i = parent(i)
    end
end

local function heapDecrease(A, i, key)
    -- hax
    -- assert(self.A[i].key < key, "new key should be smaller than current")
    A[i].key = key
    while i > 1 and A[parent(i)].key > A[i].key do
        swap(A, i, parent(i))
        i = parent(i)
    end
end

-- ================
-- Module classes
-- ================

--- `Node` class
-- @type Node
local Node = class()
Node.__eq = function(a, b) return (a.Key == b.Key and a.Data == b.Data) end
Node.__tostring = function(n) return (('Node Key :%s'):format(tostring(n.key))) end

--- Creates a new `Node`
-- @name Node:new
-- @param key an int 
-- @param data whatever it's storing
-- @return a new `Node`
-- @usage
-- local Peaque   = require 'Peaque'
-- local Node     = Peaque.Node
-- local n = Node:new(4, "a")
-- print(n) -- prints out the key
--
function Node:initialize(data, key)
    self.key, self.data = key, data
end

--- `Heap` class
-- @type Heap
local Heap = class()
-- TODO: should definitely finish this...
-- Heap.__eq = function(a, b) return  end
Heap.__tostring = function(e)
    local string = ""
    for i, v in ipairs(self.A) do
        string = string .. ": " .. v.key .. "\n"
    end
    return string
end

--- Creates a new `Heap`
-- @name Heap:new
-- @return a new empty `Heap`
-- @usage
-- local Peaque   = require 'Peaque'
-- local Heap     = Peaque.Heap
-- local h = Heap:new()
-- local h = h:insert(node)
--
function Heap:initialize()
  self.A = {}
end

--- Peeks at the largest value in the heap.
-- @return the largest heap value
-- @usage
-- TODO:
--
function Heap:peek()
    assert(#self.A > 0, "There should at least be one thing in the heap")
    return self.A[1].data
end

--- Removes the largest value in the heap.
-- @return the largest heap value
-- @usage
-- TODO:
--
function Heap:pop()
    assert(#self.A > 0, "Heap is currently empty, there is nothing to pop")
    local max = self.A[1]
    self.A[1] = self.A[#self.A]
    table.remove(self.A, #self.A)
    -- maxHeapify(self.A, 1)
    minHeapify(self.A, 1)
    return max.data
end

--- Adds a new value to the heap
-- @return nil
-- @usage
--  DOTO:
--
function Heap:push(data, key)
    local node = Node(data, -1)
    self.A[#self.A + 1] = node
    -- heapIncrease(self.A, #self.A, key)
    heapDecrease(self.A, #self.A, key)
end

function Heap:isEmpty()
    return #self.A == 0
end

function Heap:size()
    return #self.A
end

local Peaque = {
    Heap        = Heap,
    Node        = Node,
    _VERSION    = ".1.1"
}

return Peaque