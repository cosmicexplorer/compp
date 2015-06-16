fs = require 'fs'

Q = require 'q'

GetIncludePaths = require '../../../src/get-include-paths'

HeadersToSearchFor =
  c: ["stdio.h"]
  cpp: ["iostream"]

isSubset = (subset, superset) ->
  subset
    .map((el) -> superset.indexOf el)
    .filter((el) -> el isnt -1).length isnt 0

checkLanguage = (lang) ->
  Q.all(GetIncludePaths(lang).map((dir) ->
    deferred = Q.defer()
    fs.readdir dir, (err, files) ->
      if err
        deferred.reject new Error err
      else
        deferred.resolve files
    deferred.promise)).then((arr) ->
      if not isSubset(HeadersToSearchFor[lang], arr.reduce (a, b) -> a.concat b)
        throw new Error "#{lang} headers not found!"
      else
        console.log "#{lang} headers found")

# run it
checkLanguage "c"
checkLanguage "cpp"
