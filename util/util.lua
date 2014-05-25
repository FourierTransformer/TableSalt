-- Minimalistic class implementation
-- From Roland Yonaba used under MIT License
local class = function(attr)
  local klass = attr or {}
  klass.__index = klass
  klass.__call = function(_,...) return klass:new(...) end
  function klass:new(...)
    local instance = setmetatable({}, klass)
    if klass.initialize then klass.initialize(instance, ...) end
    return instance
  end
  return setmetatable(klass,{__call = klass.__call})
end


-- deepcopy for tables
-- From Penlight used under MIT License
local function complain (idx,msg)
    error(('argument %d is not %s'):format(idx,msg),3)
end

local function check_meta (val)
    if type(val) == 'table' then return true end
    return getmetatable(val)
end

local function is_iterable (val)
    local mt = check_meta(val)
    if mt == true then return true end
    return not(mt and mt.__pairs)
end

local function assert_arg_iterable (idx,val)
    if not is_iterable(val) then
        complain(idx,"iterable")
    end
end

local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    assert_arg_iterable(1,t)
    local mt = getmetatable(t)
    local res = {}
    for k,v in pairs(t) do
        if type(v) == 'table' then
            v = deepcopy(v)
        end
        res[k] = v
    end
    setmetatable(res,mt)
    return res
end

return {
    class = class,
    deepcopy = deepcopy
}