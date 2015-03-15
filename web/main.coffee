# This file provides the rendering engine for the web version. None of this code is included in the Java version.

console.log 'web startup'

Game = require 'Game'

# taken from http:#stackoverflow.com/questions/5623838/rgb-to-hex-and-hex-to-rgb
componentToHex = (c) ->
  hex = Math.floor(c * 255).toString(16)
  return if hex.length == 1 then "0" + hex else hex
rgbToHex = (r, g, b) ->
  return "#" + componentToHex(r) + componentToHex(g) + componentToHex(b)

SAVE_TIMER_MS = 3000

class NativeApp
  constructor: (@screen, @width, @height) ->
    @rgbkCache = []
    @tintedTextureCache = []
    @lastTime = new Date().getTime()
    window.addEventListener 'mousedown', @onMouseDown.bind(this), false
    window.addEventListener 'mousemove', @onMouseMove.bind(this), false
    window.addEventListener 'mouseup',   @onMouseUp.bind(this), false
    @context = @screen.getContext("2d")
    @textures = [
      # all card art
      "../res/raw/cards.png"
      # fonts
      "../res/raw/darkforest.png"
      # characters / other
      "../res/raw/chars.png"
      # help
      "../res/raw/howto1.png"
      "../res/raw/howto2.png"
      "../res/raw/howto3.png"
    ]

    @game = new Game(this, @width, @height)

    if typeof Storage != "undefined"
      state = localStorage.getItem "state"
      if state
        # console.log "loading state: #{state}"
        @game.load state

    @pendingImages = 0
    loadedTextures = []
    for imageUrl in @textures
      @pendingImages++
      console.log "loading image #{@pendingImages}: #{imageUrl}"
      img = new Image()
      img.onload = @onImageLoaded.bind(this)
      img.src = imageUrl
      loadedTextures.push img
    @textures = loadedTextures

    @saveTimer = SAVE_TIMER_MS

  onImageLoaded: (info) ->
    @pendingImages--
    if @pendingImages == 0
      console.log 'All images loaded. Beginning render loop.'
      requestAnimationFrame => @update()

  log: (s) ->
    console.log "NativeApp.log(): #{s}"

  updateSave: (dt) ->
    return if typeof Storage == "undefined"
    @saveTimer -= dt
    if @saveTimer <= 0
      @saveTimer = SAVE_TIMER_MS
      state = @game.save()
      # console.log "saving: #{state}"
      localStorage.setItem "state", state

  # from http://www.playmycode.com/blog/2011/06/realtime-image-tinting-on-html5-canvas/
  generateRGBKs: (img) ->
    w = img.width
    h = img.height
    rgbks = []

    canvas = document.createElement "canvas"
    canvas.width = w
    canvas.height = h

    ctx = canvas.getContext "2d"
    ctx.drawImage img, 0, 0

    pixels = ctx.getImageData(0, 0, w, h).data

    # 4 is used to ask for 3 images: red, green, blue and
    # black in that order.
    for rgbI in [0...4]
      canvas = document.createElement("canvas")
      canvas.width  = w
      canvas.height = h

      ctx = canvas.getContext('2d')
      ctx.drawImage img, 0, 0
      to = ctx.getImageData 0, 0, w, h
      toData = to.data

      for i in [0...pixels.length] by 4
        toData[i  ] = if (rgbI == 0) then pixels[i  ] else 0
        toData[i+1] = if (rgbI == 1) then pixels[i+1] else 0
        toData[i+2] = if (rgbI == 2) then pixels[i+2] else 0
        toData[i+3] =                     pixels[i+3]

      ctx.putImageData to, 0, 0

      # image is _slightly_ faster than canvas for this, so convert
      imgComp = new Image()
      imgComp.src = canvas.toDataURL()
      rgbks.push imgComp

    return rgbks

  generateTintImage: (textureIndex, red, green, blue) ->
    img = @textures[textureIndex]
    rgbks = @rgbkCache[textureIndex]
    if not rgbks
      rgbks = @generateRGBKs(img)
      @rgbkCache[textureIndex] = rgbks
      # console.log "generated RGBKs for #{textureIndex}"

    buff = document.createElement "canvas"
    buff.width  = img.width
    buff.height = img.height

    ctx = buff.getContext "2d"
    ctx.globalAlpha = 1
    ctx.globalCompositeOperation = 'copy'
    ctx.drawImage rgbks[3], 0, 0

    ctx.globalCompositeOperation = 'lighter'
    if red > 0
      ctx.globalAlpha = red
      ctx.drawImage rgbks[0], 0, 0
    if green > 0
      ctx.globalAlpha = green
      ctx.drawImage rgbks[1], 0, 0
    if blue > 0
      ctx.globalAlpha = blue
      ctx.drawImage rgbks[2], 0, 0

    imgComp = new Image()
    imgComp.src = buff.toDataURL()
    return imgComp

  drawImage: (textureIndex, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY, r, g, b, a) ->
    texture = @textures[textureIndex]
    if (r != 1) or (g != 1) or (b != 1)
      tintedTextureKey = "#{textureIndex}-#{r}-#{g}-#{b}"
      tintedTexture = @tintedTextureCache[tintedTextureKey]
      if not tintedTexture
        tintedTexture = @generateTintImage textureIndex, r, g, b
        @tintedTextureCache[tintedTextureKey] = tintedTexture
        # console.log "generated cached texture #{tintedTextureKey}"
      texture = tintedTexture

    @context.save()
    @context.translate dstX, dstY
    @context.rotate rot # * 3.141592 / 180.0
    anchorOffsetX = -1 * anchorX * dstW
    anchorOffsetY = -1 * anchorY * dstH
    @context.translate anchorOffsetX, anchorOffsetY
    @context.globalAlpha = a
    @context.drawImage(texture, srcX, srcY, srcW, srcH, 0, 0, dstW, dstH)
    @context.restore()

  update: ->
    now = new Date().getTime()
    dt = now - @lastTime
    @lastTime = now

    @context.clearRect(0, 0, @width, @height)
    @game.update(dt)
    renderCommands = @game.render()

    i = 0
    n = renderCommands.length
    while (i < n)
      drawCall = renderCommands.slice(i, i += 16)
      @drawImage.apply(this, drawCall)

    @updateSave(dt)

    requestAnimationFrame => @update()

  onMouseDown: (evt) ->
    @game.touchDown(evt.clientX, evt.clientY)

  onMouseMove: (evt) ->
    @game.touchMove(evt.clientX, evt.clientY)

  onMouseUp: (evt) ->
    @game.touchUp(evt.clientX, evt.clientY)

screen = document.getElementById 'screen'
resizeScreen = ->
  desiredAspectRatio = 16 / 9
  currentAspectRatio = window.innerWidth / window.innerHeight
  if currentAspectRatio < desiredAspectRatio
    screen.width = window.innerWidth
    screen.height = Math.floor(window.innerWidth * (1 / desiredAspectRatio))
  else
    screen.width = Math.floor(window.innerHeight * desiredAspectRatio)
    screen.height = window.innerHeight
resizeScreen()
# window.addEventListener 'resize', resizeScreen, false

app = new NativeApp(screen, screen.width, screen.height)
