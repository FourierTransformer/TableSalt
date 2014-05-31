TableSalt
=========
TableSalt is a constraint satisfaction framework. If I did it right, it should be fairly easy to adapt to any constraint satisfaction problem.

## Installation
To have the latest version of TableSalt, it an be installed as a submodule:

    git submodule add git://github.com/FourierTransformer/TableSalt.git

after which you need to do a `git submodule update --recursive` to fully initialize it.

or you could just clone it and include it in your project:

    git clone git://github.com/FourierTransformer/TableSalt.git

and to include it in your project: `local TableSalt = require('TableSalt/TableSalt')`

## Quick Example
TableSalt was designed to be user friendly. As such, you can setup the Australia Coloring Problem as such:

```
local australia = TableSalt:new({"Red", "Green", "Blue"}, {"WA", "NT", "SA", "Q", "NSW", "V", "T"})
australia:addConstraintByNames({"WA", "NT", "SA"}, TableSalt.allDiff)
australia:addConstraintByNames({"Q", "NT", "SA"}, TableSalt.allDiff)
australia:addConstraintByNames({"Q", "NSW", "SA"}, TableSalt.allDiff)
australia:addConstraintByNames({"V", "NSW", "SA"}, TableSalt.allDiff)
```
and since the Australia Coloring Problem doesn't benefit from domain reduction off the bat, and then you solve it via forward checking: `australia:solveForwardCheck()`

after which you can print the results -- `australia:print()` -- and get the following:

```
WA  Green
NT  Blue
SA  Red
Q   Green
NSW Blue
V   Green
T   Red
```

and it's all nice and colored correctly! TableSalt can also accept input in many other ways, be sure to check out the documentaion [[MAKE THIS A LINK]] and some example projects to get a feel for what it can do.

## Examples of TableSalt in Use
Here a few projects I made to test out the functionality of TableSalt:

- SudokuSolver
- KakuroSolver
- KenKenSolver
- TextbookCSPs
