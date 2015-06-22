Transform = require 'transform-stream-extensions'

module.exports =
class ConcatBackslashNewlinesStream extends Transform
  constructor: (opts = {}) ->
    super opts

    @curBlock = ""

  joinBackslashNewlines: (strArr) ->
    retArr = []
    i = 0
    while i < strArr.length
      el = strArr[i]
      while el isnt "" and el[el.length - 1] is "\\"
        el += '\n' + strArr[i+1]
        ++i
      retArr.push el + '\n'
      ++i
    retArr

  cutByLines: (str) ->
    @curBlock += str
    res = @curBlock.split('\n')
    res = @joinBackslashNewlines res
    numToPush = res.length - 2
    @curBlock = res[res.length - 1]
    for i in [0..(numToPush)] by 1
      @push res[i]

  _transform: (chunk, enc, cb) ->
    @cutByLines chunk.toString()
    cb?()
