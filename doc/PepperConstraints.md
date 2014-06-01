#Pepper Constraints
## A Quick Overview
Pepper constraints are functions that reduce domains for constraint satisfaction problems, such as the provided `Pepper.allDiff` (for the all different constraint) and `Pepper.setVal` (for any unary constraint). TableSalt allows you to write your own constraint functions, to allow flexibility in the problems you want to solve. Each pepper constraint is then passed in to the framework along with the variables it modifies before solving.

## Writing Pepper Constraints
Declaring a new pepper constraint is easy:

```lua
function newConstraint(section, board, ...)
```

The TableSalt framework will always pass in the `section` and `board` for each constraint function. So be sure that these are the first two arguments declared when creating a new constraint function! The `section` is a table of id's corresponding to variables that that constraint will be modifying and the `board` is the current TableSalt instance that is being used. Pepper constraint functions also allow for multiple additional parameters to be passed in, hence the `...` in the function decleration. Constraints should be designed to work in a variety of situations, they are applied to certain variables (called a `section`) when they are passed in to the framework.

The main thing about pepper constraints are that they should return a table of tables of the new domains that correspond to the `section` ids passed in to the constraint. While that sounds confusing let's break it down. Take the `Pepper.setVal` constraint for example:

```lua
function Pepper.setVal(section, board, val)
    local allValues = {}
    for i = 1, #section do
        allValues [ #allValues+1 ] = {val}
    end
    return allValues
end
```

It's important that the table that is returned, `allValues`, is the same length as `section`. The first element in `allValues` corresponds to the new domain (which is always given as a table) of the first element (which will be an id for a constraint) in `section`. Since this is the `setVal` constraint, each domain is reduced to exactly one value.

It's also worth noting that if a constraint fails on a specific id, the associated domain should be an empty table: `{}`. Ex: The section `{1, 3, 4}` fails the constraint on the third element, the table the constraint returns could look like this: `{ {1, 4, 3}, {2}, {} }`.

### Helpful functions when writing constraints
Since the pepper constraints pass in an instance of `TableSalt`, some of the functions available should be quite useful. Most particularly `TableSalt:getValueByID()` and `TableSalt:getDomainByID()`. Here's a quick example of how they could be used:

```lua
function newConstraint(section, board)
    for ind, id in ipairs(section) do
        local currentValue = board:getValueByID(id)
        local currentDomain = board:getDomainByID(id)
        -- some more stuff
    end
end
```

This will iterate through all the variables's ids that were passed in and do magical things with their associated values and domains!

## Passing in Pepper Constraints
There are a multitude of functions that are used to pass in pepper constraints:

- `TableSalt:addConstraintByIDs`
- `TableSalt:addConstraintByPairs`
- `TableSalt:addConstraintByNames`
- `TableSalt:addConstraintForEachRow`
- `TableSalt:addConstraintForEachColumn`
- `TableSalt:addConstraintForAll`

The first three (`addConstraintByIDs`, `addConstraintByPairs`, and `addConstraintByNames`) in the list all follow a similar structure for passing in pepper constraints:

```lua
    --code
    addConstraintByX(section, pepperConstraint, ...)
    --more code
```

The `section` can be passed in through a variety of methods, check the documentation on those specific functions for more information on that. The `pepperConstraint` is simply the name of the `pepperConstraint` (be sure not to pass in any arguments here). The `...` represents any additional arguments that are required to run the constraint.

The other three (`addConstraintForEachRow`, `addConstraintForEachColumn`, and `addConstraintForAll`) only pass in the `pepperConstraint` and any additional arguments. 

Here's a quick example on how to pass in `Pepper.setVal(section, board, val)` which takes in the additional parameter 'val':

```lua
    -- some crazy game that is played on 5 squares where each square have the values 1-5
    local crazyGame = TableSalt:new({1, 2, 3, 4, 5}, 5)
    -- squares 1, 3, and 5 all need to be set to 5 for some reason
    crazyGame:addConstraintByIDs({1, 3, 5}, Pepper.setVal, 5)
```

Any additional parameters can just be appended and TableSalt should take care of the rest!
