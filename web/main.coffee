console.log 'web startup'

Game = require 'Game'

class NativeApp
  constructor: (@screen, @width, @height) ->
    @lastTime = new Date().getTime()
    window.addEventListener 'mousedown', @onMouseDown.bind(this), false
    window.addEventListener 'mousemove', @onMouseMove.bind(this), false
    window.addEventListener 'mouseup',   @onMouseUp.bind(this), false
    @context = @screen.getContext("2d")
    @textures =
      cards: "../res/raw/cards.png"
      unispace: "../res/raw/unispace.png"
      square: "../res/raw/square.png"

    @game = new Game(this, @width, @height)

    @pendingImages = 0
    for imageName, imageUrl of @textures
      @pendingImages++
      console.log "loading image #{@pendingImages} '#{imageName}': #{imageUrl}"
      @textures[imageName] = new Image()
      @textures[imageName].onload = @onImageLoaded.bind(this)
      @textures[imageName].src = imageUrl

  onImageLoaded: (info) ->
    @pendingImages--
    if @pendingImages == 0
      console.log 'All images loaded. Beginning render loop.'
      requestAnimationFrame => @update()

  log: (s) ->
    console.log "NativeApp.log(): #{s}"

  drawImage: (textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY) ->
    @context.save()
    @context.translate dstX, dstY
    @context.rotate rot # * 3.141592 / 180.0
    anchorOffsetX = -1 * anchorX * dstW
    anchorOffsetY = -1 * anchorY * dstH
    @context.translate anchorOffsetX, anchorOffsetY
    @context.drawImage(@textures[textureName], srcX, srcY, srcW, srcH, 0, 0, dstW, dstH)
    @context.restore()

  update: ->
    now = new Date().getTime()
    dt = now - @lastTime
    @lastTime = now

    @context.clearRect(0, 0, @width, @height)
    @game.update(dt)
    @game.render()

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
