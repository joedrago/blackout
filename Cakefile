fs = require 'fs'
http = require 'http'
mkdirp = require 'mkdirp'
util = require 'util'
watch = require 'node-watch'
{spawn, exec} = require 'child_process'

rhinoLib = 'libs/js.jar'
outputClassDir = 'bin/classes'
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

buildGameBundle = (cb) ->
  cmdline = getCoffeeScriptCmdline(gameSrcPath)
  util.log "Bundling (game): #{cmdline.names}"
  mkdirp.sync(outputClassDir)
  shell true, """
    browserify -o #{outputClassDir}/Script.js -t coffeeify #{cmdline.sources}
    coffee -bcp ./#{gameSrcPath}/boot.coffee >> #{outputClassDir}/Script.js
  """, ->
    cb() if cb?

buildWebBundle = (cb) ->
  gameCmdline = getCoffeeScriptCmdline(gameSrcPath)
  webCmdline = getCoffeeScriptCmdline(webSrcPath)
  util.log "Bundling (web): #{webCmdline.names}"
  mkdirp.sync(outputClassDir)
  shell false, """
    browserify -o #{outputClassDir}/web.js #{gameCmdline.externals} -t coffeeify #{webCmdline.sources}
  """, ->
    cb() if cb?

buildJavaClasses = (cb) ->
  util.log "Generating Java classes"
  mkdirp.sync(outputClassDir)
  shell true, """
    javac -target 1.5 -source 1.5 -d #{outputClassDir} #{bridgeSrcPath}/NativeApp.java #{bridgeSrcPath}/BaseScript.java
    java -cp #{rhinoLib}:#{outputClassDir} org.mozilla.javascript.tools.jsc.Main -opt -1 -implements com.jdrago.blackout.bridge.BaseScript -package com.jdrago.blackout.bridge #{outputClassDir}/Script.js
  """, ->
    cb() if cb?

task 'build', 'build JS bundle', (options) ->
  buildGameBundle ->
    buildJavaClasses()

task 'web', 'build web version', (options) ->
  buildGameBundle ->
    buildWebBundle()

option '-p', '--port [PORT]', 'Dev server port'

task 'server', 'run web server', (options) ->
  buildWebBundle ->
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
      buildGameBundle()

    watch webSrcPath, (filename) ->
      util.log "Source code #{filename} changed, regenerating bundle..."
      buildWebBundle()
