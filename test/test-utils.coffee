# this outputs color whether or not it's through a terminal
colors = require 'cli-color'
Transform = require 'transform-stream-extensions'

module.exports =
  outputDiffs: (diffsList, stream) ->
    diffsList.forEach (part) ->
      color = switch
        when part.added then 'green'
        when part.removed then 'red'
        else 'white'
      stream.write colors[color](part.value)

  makeTransformStream: (objectMode = null, transformFunc = null) ->
    class NewTransformStream extends Transform
      constructor: (opts = {}) ->
        switch objectMode
          when "read"
            opts.objectMode = yes
            opts.readableObjectMode = yes
          when "write"
            opts.objectMode = yes
            opts.writeableObjectMode = yes
          when "both"
            opts.objectMode = yes
            opts.readableObjectMode = yes
            opts.writeableObjectMode = yes
        super opts

      _transform: (chunk, enc, cb) ->
        if objectMode is "write" or objectMode is "both"
          obj = chunk
        else
          obj = chunk.toString()
        if transformFunc
          @push transformFunc(obj)
        else
          @push obj
        cb?()
