#TODO: more namespacing
define ["underscore", "backbone"], (_, Backbone) ->
  window.events = _.clone(Backbone.Events)
