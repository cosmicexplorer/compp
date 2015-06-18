# this outputs color whether or not it's through a terminal
colors = require 'cli-color'

module.exports =
outputDiffs: (diffsList, stream) ->
  diffsList.forEach (part) ->
    color = switch
      when part.added then 'green'
      when part.removed then 'red'
      else 'grey'
    stream.write colors[color](part.value)
