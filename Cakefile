fs = require 'fs'
{spawn, exec} = require 'child_process'

rhinoLib = 'libs/js.jar'
outputClassDir = 'bin/classes'
bridgeSrcPath = 'src/com/jdrago/blackout/bridge'

shell = (cmds, callback) ->
  cmd = cmds.split(/\n/).join(' && ')
  console.log cmd
  exec cmd, (err, stdout, stderr) ->
    console.log trimStdout if trimStdout = stdout.trim()
    if err
        console.error stderr.trim()
        process.exit(1)
    callback() if callback

task 'build', 'build JS bundle', (options) ->
  sources = ''
  names = []
  for filename in fs.readdirSync('cs')
    if matches = filename.match(/(\S+).coffee/)
      continue if matches[1] == 'boot'
      names.push matches[1]
      sources += "-r ./cs/#{filename}:#{matches[1]} "
  console.log "Bundling: #{names.join(', ')}"
  shell """
    mkdir -p #{outputClassDir}
    browserify -o #{outputClassDir}/Script.js -t coffeeify #{sources}
    coffee -bcp ./cs/boot.coffee >> #{outputClassDir}/Script.js
    javac -target 1.5 -source 1.5 -d #{outputClassDir} #{bridgeSrcPath}/NativeApp.java #{bridgeSrcPath}/BaseScript.java
    java -cp #{rhinoLib}:#{outputClassDir} org.mozilla.javascript.tools.jsc.Main -opt -1 -implements com.jdrago.blackout.bridge.BaseScript -package com.jdrago.blackout.bridge #{outputClassDir}/Script.js
  """
