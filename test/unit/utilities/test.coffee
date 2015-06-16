utils = require '../../../src/utilities'

inputArr = [ 5,  1,  5,  4,  1,  8,  4,  2,  10,  4,  1,  3,  10,  9,  2,  9,
  5,  10,  9,  10,  5,  4,  4,  8,  10,  1,  5,  9,  5,  5,  7,  2,  6,  1,  7,
  1,  6,  3,  9,  4,  3,  4,  5,  8,  5,  10,  7,  4,  2,  8,  5 ]

res = utils.uniquify(inputArr).sort((a, b) -> a > b)

if [1..10].every((el) -> res.indexOf(el) + 1 == el)
  console.log res
else
  throw new Error "array was not uniquified!"
