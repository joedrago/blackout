Animation = require 'Animation'

class Button
  constructor: (@game, @font, @textHeight, @x, @y, @text, @cb) ->
    @anim = new Animation {
      speed: { s: 3 }
      s: 0
    }
    @color = { r: 1, g: 1, b: 1, a: 0 }

  update: (dt) ->
    return @anim.update(dt)

  render: ->
    @color.a = @anim.cur.s
    @game.spriteRenderer.render "button0", @x, @y, 0, @textHeight * 1.5, 0, 0.5, 0.5, @game.colors.white, =>
      # pulse button anim,
      @anim.cur.s = 1
      @anim.req.s = 0
      # then call callback
      newText = null
      if @cb
        newText = @cb()
      if newText
        @text = newText
    @game.spriteRenderer.render "button1", @x, @y, 0, @textHeight * 1.5, 0, 0.5, 0.5, @color
    @game.fontRenderer.render @font, @textHeight, @text, @x, @y, 0.5, 0.5, @game.colors.buttontext

module.exports = Button
