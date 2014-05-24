mewlTemplate = require("../templates/MewlNotification.html")

# Displays a little modal-like alert box with
module.exports.MewlNotification = class MewlNotification extends Backbone.View

  template: mewlTemplate
  className: "growl"

  events:
    "click .j-close": "hide"

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))

    # defaults
    @closable = true
    @classes = "notif-white"
    @position = "bottom right"
    @padding = 10
    @lifespan = opts.lifespan || 3000

    @set(opts)
    @$el.addClass @position
    @place().show()

  render: ->
    @$el.html @template(
      classes: @classes
      title: @title
      body: @body
      closable: @closable
    )

  set: (opts) ->
    _.extend this, opts
    @render()

  show: ->
    self = this
    $("body").append @$el
    _.defer => @$el.addClass "shown"

    setTimeout @hide, @lifespan if @lifespan != Infinity

    return @ # for chaining

  hide: ->
    @$el.on 'webkitTransitionEnd transitionend msTransitionEnd oTransitionEnd', => @$el.remove()
    @$el.addClass "slide-right"

    return @ # for chaining

  place: ->
    $otherGrowls = $(".growl:visible." + @position.replace(" ", ".")) # finds all with the same position settings as ours

    cssString = if @position.indexOf("bottom") != -1
      "bottom"
    else
      "top"

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

    return @ # for chaining
