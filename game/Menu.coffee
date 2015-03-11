Button = require 'Button'

class Menu
  constructor: (@game, @background, @actions) ->
    @buttons = []

    buttonStartY = @game.height / 3

    slice = (@game.height - buttonStartY) / (@actions.length + 1)
    currY = buttonStartY + slice
    for action in @actions
      button = new Button(@game, "unispace", @game.height / 15, @game.center.x, currY, action.text, action.cb)
      @buttons.push button
      currY += slice

  update: (dt) ->
    updated = false
    for button in @buttons
      if button.update(dt)
        updated = true
    return false

  render: ->
    @game.spriteRenderer.render @background, 0, 0, @game.width, @game.height, 0, 0, 0, @game.colors.white
    for button in @buttons
      button.render()

module.exports = Menu
