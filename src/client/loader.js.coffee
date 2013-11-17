define (require, exports, module) ->
  _ = require("underscore")
  $ = require("jquery")
  config = module.config()
  mods = []
  section = _.template($("#sectionTemplate").html())
  button = _.template($("#buttonTemplate").html())
  _.each config.modules, (val) ->
    val = _.defaults(val,
      active: false
    )
    s = $(section(val)).appendTo($("#panes"))
    s.hide()  unless val.active
    $(button(val)).appendTo $("#buttons")
    mods.push _.extend(val,
      view: "modules/" + val.name + "/client"
    )


  #Preload modules
  require _.map(mods, (mod) ->
    mod.view
  ), ->

  mods
