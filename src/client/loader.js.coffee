defined_modules = require('./config.coffee').Modules

module.exports.Loader = class Loader


  constructor: ->
    @modules = []
    section = _.template($("#sectionTemplate").html())
    button = _.template($("#buttonTemplate").html())

    _.each defined_modules, (val) =>
      val = _.defaults val, active: false
      s = $(section(val)).appendTo($("#panes"))
      s.hide()  unless val.active
      $(button(val)).appendTo $("#module-buttons")
      @modules.push _.extend(val,
        view: "modules/" + val.name + "/client"
      )

    @modules
