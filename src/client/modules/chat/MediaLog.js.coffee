mediaLogTemplate            = require("./templates/mediaLog.html")
linkedImageTemplate         = require("./templates/linkedImage.html")
youtubeTemplate             = require("./templates/youtube.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES

module.exports.MediaLog = class MediaLog extends Backbone.View

  makeYoutubeThumbnailURL: (vID) ->
    window.location.protocol + "//img.youtube.com/vi/" + vID + "/0.jpg"
  makeYoutubeURL: (vID) ->
    window.location.protocol + "//youtube.com/v/" + vID

  mediaLogTemplate: mediaLogTemplate
  youtubeTemplate: youtubeTemplate
  linkedImageTemplate: linkedImageTemplate

  className: 'linklog'

  events:
    "click .clearMediaLog": "clearMediaContents"
    "click .disableMediaLog, .opt-out": "disallowMediaAutoload"
    "click .maximizeMediaLog": "nullMediaAutoload"
    "click .media-opt-in .opt-in": "allowMediaAutoload"
    "click .youtube.imageThumbnail": "showYoutubeVideo"

  initialize: (opts) ->
    _.bindAll this
    _.extend this, opts

    throw "No room supplied for MediaLog" unless opts.room

    MediaItem = class MediaItem extends Backbone.Model
      idAttribute: 'url'

      initialize: ->
        _.bindAll this
        @view = new Backbone.View
        @render()

      render: ->
        url = @get('url')
        html = switch @get('type')
          when 'link'
            "<a rel='noreferrer' href='#{url}' target='_blank'>#{url}</a>"
          else
            console.log @toJSON()
            linkedImageTemplate(@toJSON())

        @view.$el.html(html)


    console.log window.localStorage.getItem("autoloadMedia:#{@room}"), @determineAutoloadStatus()
    @state = new Backbone.Model
      autoloadMedia: @determineAutoloadStatus()

    MediaCollection = class MediaCollection extends Backbone.Collection
      comparator: 'timestamp'
      model: MediaItem

    @media = new MediaCollection()
    @media.on 'add change reset', @renderMedia

    window.events.on "linklog:#{@room}:link", (opts) =>
      @media.add new MediaItem(_.extend(opts, {type: 'link'}))
    window.events.on "linklog:#{@room}:youtube", (opts) =>
      @media.add new MediaItem(_.extend(opts, {type: 'youtube'}))
    window.events.on "linklog:#{@room}:image", (opts) =>
      @media.add new MediaItem(_.extend(opts, {type: 'image'}))

    @render()

  determineAutoloadStatus: ->
    stored = window.localStorage.getItem("autoloadMedia:#{@room}")
    return "unknown" if !stored
    return true if (stored == "true") or (stored == true)
    return false

  render: ->
    @$el.html @mediaLogTemplate()

  renderMedia: ->
    if @state.get('autoloadMedia')
      $body = @$el.find(".body")
      for model in @media.models.reverse()
        $body.append model.view.$el

  clearMediaContents: ->
    @$el.find(".body").html("")

  disallowMediaAutoload: ->
    @state.set('autoloadMedia', false)
    @clearMediaContents()
    window.localStorage.setItem "autoloadMedia:#{@room}", false

  nullMediaAutoload: ->
    @state.set('autoloadMedia', "unknown")
    window.localStorage.clear "autoloadMedia:#{@room}"

  allowMediaAutoload: ->
    @state.set('autoloadMedia', true)
    @renderMedia()
    window.localStorage.setItem "autoloadMedia:#{@room}", true

  showYoutubeVideo: (ev) ->
    $(ev.currentTarget).hide()
    $(ev.currentTarget).siblings(".video").show()
