define ["jquery", "underscore", "backbone", "text!modules/user_info/templates/userPopup.html", "events"], ($, _, Backbone, popupTemplate) ->
  UserDataPopup = Backbone.View.extend(
    className: "backdrop"
    template: _.template(popupTemplate)
    events:
      click: "remove"

    initialize: (opts) ->
      _.bindAll this
      _.extend this, opts
      console.log @client.attributes
      @$el.html @template(@client.attributes)
      $("body").append @$el
  )
  UserData = Backbone.View.extend(initialize: ->
    console.log popupTemplate
    window.events.on "view_profile", (data) ->
      console.log data
      client = data.clients.findWhere(id: data.uID)
      modal = new UserDataPopup(client: client)

    window.events.on "edit_profile", (data) ->
      console.log data
      client = data.clients.findWhere(id: data.uID)
      modal = new UserDataPopup(
        client: client
        editable: true
      )

  )
  userData = new UserData() # singleton
