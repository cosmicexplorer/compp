# native
fs = require 'fs'
path = require 'path'
# npm
Transform = require 'transform-stream-extensions'
# local
ConcatBackslashNewlineStream = require "./concat-backslash-newline-stream"
utils = require './utilities'
GetIncludePaths = require './get-include-paths'

module.exports =
class PreprocessStream extends Transform
  constructor: (@filename, @language, @defines = {}, includeDirs = {},
    opts = {}) ->

    opts.readableObjectMode = yes
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

  _transform: (chunk, enc, cb) ->
    str = chunk.toString()
    @processLine(str)
    cb?()