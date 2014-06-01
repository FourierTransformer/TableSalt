TableSalt
=========
TableSalt is a constraint satisfaction framework. It allows you to write custom constraint functions (Pepper Constraints) that can be used to solve practically any constraint satisfaction problem.

Keep reading and check out the [documentation](http://FourierTransformer.github.io/TableSalt) for more info.

## Installation
To have the latest version of TableSalt, it an be installed as a submodule:

    git submodule add git://github.com/FourierTransformer/TableSalt.git

after which you need to do a `git submodule update --init --recursive` to fully initialize it.

or you could just clone it and include it in your project:

    git clone git://github.com/FourierTransformer/TableSalt.git

and to include it in your project: 

>```lua
local CSP = require('TableSalt/TableSalt')
local TableSalt = CSP.TableSalt
local Pepper = CSP.Pepper
```

## Quick Example
TableSalt was designed to be user friendly. As such, you can setup the Australia Coloring Problem as such:

>```lua
local australia = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
australia:addConstraintByNames({"WA", "NT", "SA"}, Pepper.allDiff)
australia:addConstraintByNames({"Q", "NT", "SA"}, Pepper.allDiff)
australia:addConstraintByNames({"Q", "NSW", "SA"}, Pepper.allDiff)
australia:addConstraintByNames({"V", "NSW", "SA"}, Pepper.allDiff)
```

and since the Australia Coloring Problem doesn't benefit from domain reduction off the bat, and then you solve it via forward checking: `australia:solveForwardCheck()`

after which you can print the results -- `australia:print()` -- and get the following:

>```
WA  Green
NT  Blue
SA  Red
Q   Green
NSW Blue
V   Green
T   Red
```

and it's all nice and colored correctly! TableSalt can also accept input in many other ways, be sure to check out the [documentaion](http://FourierTransformer.github.io/TableSalt/) and some example projects to get a feel for what it can do.

## Examples of TableSalt in Use
Here a few projects I made to test out the functionality of TableSalt:

- [SudokuSolver](http://github.com/FourierTransformer/SudokuSolver)
