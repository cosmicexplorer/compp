module.exports =
uniquify: (arr) ->
  arr = arr.sort()
  i = 0
  while i < arr.length
    if arr[i] is arr[i + 1]
      arr.splice i + 1, 1
    else
      ++i
  return arr
