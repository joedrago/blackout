Button = require 'Button'

class Menu
  constructor: (@game, @title, @background, @color, @actions) ->
    @buttons = []
    @buttonNames = ["button0", "button1"]

    buttonSize = @game.height / 20
    buttonStartY = @game.height / 3

    slice = (@game.height - buttonStartY) / (@actions.length + 1)
    currY = buttonStartY + slice
    for action in @actions
      button = new Button(@game, @buttonNames, @game.font, buttonSize, @game.center.x, currY, action)
      @buttons.push button
      currY += slice

  update: (dt) ->
    updated = false
    for button in @buttons
      if button.update(dt)
        updated = true
    return updated

  render: ->
    @game.spriteRenderer.render @background, 0, 0, @game.width, @game.height, 0, 0, 0, @color
    titleHeight = @game.height / 8
    titleOffset = titleHeight
    @game.fontRenderer.render @game.font, titleHeight, @title, @game.center.x, titleOffset, 0.5, 0, @game.colors.white
    for button in @buttons
      button.render()

module.exports = Menu
