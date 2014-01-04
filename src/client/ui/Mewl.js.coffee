mewlTemplate = require("../templates/MewlNotification.html")


  # Displays a little modal-like alert box with
module.exports.MewlNotification = class MewlNotification extends Backbone.View

  template: mewlTemplate
  className: "growl"

  initialize: (opts) ->
    _.bindAll this

    # defaults
    @position = "bottom right"
    @padding = 10
    @lifespan = opts.lifespan or 3000

    # override defaults
    _.extend this, opts
    @$el.html @template(
      title: opts.title
      body: opts.body
    )
    @$el.addClass @position
    @place().show()

  show: ->
    self = this
    $("body").append @$el
    _.defer ->
      self.$el.addClass "shown"

    setTimeout @hide, @lifespan
    this

  hide: ->
    self = this
    @$el.removeClass "shown"
    window.events.trigger "growl:hide",
      height: parseInt(self.$el.outerHeight(), 10)

    setTimeout ->
      self.remove()


  place: ->
    cssString = undefined
    curValue = undefined
    $otherEl = undefined
    $otherGrowls = $(".growl:visible." + @position.replace(" ", ".")) # finds all with the same position settings as ours
    if @position.indexOf("bottom") isnt -1
      cssString = "bottom"
    else
      cssString = "top"
    max = -Infinity
    heightOfMax = 0

    # find the offset of the highest visible growl
    # and place ourself above it
    i = 0

    while i < $otherGrowls.length
      $otherEl = $($otherGrowls[i])
      curValue = parseInt($otherEl.css(cssString), 10)
      if curValue > max
        max = curValue
        heightOfMax = $otherEl.outerHeight()
      i++
    max += heightOfMax
    max += @padding # some padding
    @$el.css cssString, max
    this
