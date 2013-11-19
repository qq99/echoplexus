#TODO: more namespacing
module.exports = ->
  window.events = _.clone(Backbone.Events)
