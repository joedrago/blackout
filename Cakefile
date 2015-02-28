{spawn, exec} = require 'child_process'

shell = (cmds, callback) ->
  cmds = [cmds] if Object::toString.apply(cmds) isnt '[object Array]'
  exec cmds.join(' && '), (err, stdout, stderr) ->
    console.log trimStdout if trimStdout = stdout.trim()
    if err
        console.error stderr.trim()
        process.exit(err)
    callback() if callback


task 'build', 'build JS bundle', (options) ->
  shell [
    'mkdir -p bin/classes'
    'browserify -o bin/classes/Script.js -t coffeeify -r ./cs/SomeClass.coffee:SomeClass'
    'coffee -bcp ./cs/boot.coffee >> bin/classes/Script.js'
    #'javac -d bin/classes src/com/jdrago/blackout/bridge/NativeApp.java src/com/jdrago/blackout/bridge/BaseScript.java'
    'java -cp libs/js.jar:bin/classes org.mozilla.javascript.tools.jsc.Main -opt -1 -implements com.jdrago.blackout.bridge.BaseScript -package com.jdrago.blackout.bridge bin/classes/Script.js'
  ]

