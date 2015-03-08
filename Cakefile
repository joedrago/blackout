fs = require 'fs'
http = require 'http'
mkdirp = require 'mkdirp'
util = require 'util'
watch = require 'node-watch'
{spawn, exec} = require 'child_process'

outputBinDir = 'bin'
outputResDir = 'res/raw'
bridgeSrcPath = 'src/com/jdrago/blackout/bridge'
gameSrcPath = 'game'
webSrcPath = 'web'

shell = (exitOnFailure, cmds, cb) ->
  cmd = cmds.split(/\n/).join(' && ')
  util.log cmd
  exec cmd, (err, stdout, stderr) ->
    util.log trimStdout if trimStdout = stdout.trim()
    if err
      console.error stderr.trim()
      if exitOnFailure
        process.exit(1)
    cb() if cb?

getCoffeeScriptCmdline = (dir) ->
  sources = ''
  names = []
  externals = ''
  for filename in fs.readdirSync(dir)
    if matches = filename.match(/(\S+).coffee/)
      continue if matches[1] == 'boot'
      names.push matches[1]
      sources += "-r ./#{dir}/#{filename}:#{matches[1]} "
      externals += "-x #{matches[1]} "
  return {
    sources: sources
    names: names.join(', ')
    externals: externals
  }

buildGameBundle = (exitOnFailure, cb) ->
  cmdline = getCoffeeScriptCmdline(gameSrcPath)
  util.log "Bundling (game): #{cmdline.names}"
  # mkdirp.sync(outputBinDir)
  shell exitOnFailure, """
    browserify -o #{outputResDir}/script.js -t coffeeify #{cmdline.sources}
    coffee -bcp ./#{gameSrcPath}/boot.coffee >> #{outputResDir}/script.js
  """, ->
    cb() if cb?

buildWebBundle = (exitOnFailure, cb) ->
  gameCmdline = getCoffeeScriptCmdline(gameSrcPath)
  webCmdline = getCoffeeScriptCmdline(webSrcPath)
  util.log "Bundling (web): #{webCmdline.names}"
  mkdirp.sync(outputBinDir)
  shell exitOnFailure, """
    browserify -o #{outputBinDir}/web.js #{gameCmdline.externals} -t coffeeify #{webCmdline.sources}
  """, ->
    cb() if cb?

task 'build', 'build JS bundle', (options) ->
  buildGameBundle true

task 'web', 'build web version', (options) ->
  buildGameBundle true, ->
    buildWebBundle()

option '-p', '--port [PORT]', 'Dev server port'

task 'server', 'run web server', (options) ->
  buildGameBundle false, ->
    buildWebBundle false, ->
      options.port ?= 9000
      util.log "Starting server at http://localhost:#{options.port}/"

      nodeStatic = require 'node-static'
      file = new nodeStatic.Server '.'
      httpServer = http.createServer (request, response) ->
        request.addListener 'end', ->
          file.serve(request, response);
        .resume()

      httpServer.listen options.port

      watch gameSrcPath, (filename) ->
        util.log "Source code #{filename} changed, regenerating bundle..."
        buildGameBundle(false)

      watch webSrcPath, (filename) ->
        util.log "Source code #{filename} changed, regenerating bundle..."
        buildWebBundle(false)
