Backbone = require('backbone')
GLOBAL_EVENTBUS = undefined

module.exports.EventBus = ->
  GLOBAL_EVENTBUS = new Backbone.Model if !GLOBAL_EVENTBUS

  return GLOBAL_EVENTBUS
