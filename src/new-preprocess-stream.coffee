# native
fs = require 'fs'
path = require 'path'
# npm
Transform = require 'transform-stream-extensions'
# local
utils = require './utilities'
GetIncludePaths = require './get-include-paths'

module.exports =
class PreprocessStream extends Transform
  constructor: (@filename, @language, @defines = {}, includeDirs = {},
    opts = {}) ->
    opts.objectMode = yes
    super opts

    @includeDirs =
      system: utils.uniquify(includeDirs.system or GetIncludePaths @language)
      local: utils.uniquify(["."].concat includeDirs.local or [])

    @lineNum = 1
    @inComment = no
    @lineText = ""

    @includeOccurDict = {}

    @ifStack = []

  processLine: (str) ->
    @push str

  _transform: (obj, enc, cb) ->
    @processLine(obj)
    cb?()
