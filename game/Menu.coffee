Button = require 'Button'

class Menu
  constructor: (@game, @background, @actions) ->
    @buttons = []

    buttonSize = @game.height / 20
    buttonStartY = @game.height / 3

    slice = (@game.height - buttonStartY) / (@actions.length + 1)
    currY = buttonStartY + slice
    for action in @actions
      button = new Button(@game, @game.font, buttonSize, @game.center.x, currY, action.text, action.cb)
      @buttons.push button
      currY += slice

  update: (dt) ->
    updated = false
    for button in @buttons
      if button.update(dt)
        updated = true
    return updated

  render: ->
    @game.spriteRenderer.render @background, 0, 0, @game.width, @game.height, 0, 0, 0, @game.colors.white
    for button in @buttons
      button.render()

module.exports = Menu
