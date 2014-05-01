mediaLogTemplate            = require("./templates/mediaLog.html")
linkedImageTemplate         = require("./templates/linkedImage.html")
youtubeTemplate             = require("./templates/youtube.html")
REGEXES                     = require("../../regex.js.coffee").REGEXES

module.exports.MediaLog = class MediaLog extends Backbone.View

  mediaLogTemplate: mediaLogTemplate

  className: 'linklog'

  events:
    "click .clearMediaLog": "clearMediaContents"
    "click .disableMediaLog, .opt-out": "disallowMediaAutoload"
    "click .maximizeMediaLog": "nullMediaAutoload"
    "click .media-opt-in .opt-in": "allowMediaAutoload"
    "click .youtubeEmbed .play-icon": "showYoutubeVideo"

  initialize: (opts) ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))
    _.extend this, opts

    throw "No room supplied for MediaLog" unless opts.room

    MediaItem = class MediaItem extends Backbone.Model
      # idAttribute: 'url' # guarantees uniqueness, potentially not desirable, conflicts with webshot URL

      makeYoutubeThumbnailURL: (vID) ->
        window.location.protocol + "//img.youtube.com/vi/" + vID + "/0.jpg"
      makeYoutubeURL: (vID) ->
        window.location.protocol + "//youtube.com/v/" + vID

      initialize: ->
        _.bindAll.apply(_, [this].concat(_.functions(this)))
        @view = new Backbone.View
        @sequence++ # when things are added at EXACTLY the same time, we'll add them in the order they are sent
        @render()

      render: ->
        url = @get('url')
        html = switch @get('type')
          when 'link'
            "<a rel='noreferrer' href='#{url}' target='_blank'>#{url}</a>"
          when 'image'
            linkedImageTemplate(@toJSON())
          when 'youtube'
            vID = REGEXES.urls.youtube.exec(url)[5]
            REGEXES.urls.youtube.exec "" # clear global state
            youtubeTemplate(
              vID: vID
              img_src: @makeYoutubeThumbnailURL(vID)
              src: @makeYoutubeURL(vID)
              originalSrc: url
            )

        @view.$el.html(html)

    @state = new Backbone.Model
      autoloadMedia: @determineAutoloadStatus()

    MediaCollection = class MediaCollection extends Backbone.Collection
      comparator: 'timestamp'
      model: MediaItem

    @media = new MediaCollection()
    @media.on 'add change reset', @renderMedia

    _.each ['link', 'youtube', 'image'], (variant) =>
      window.events.on "linklog:#{@room}:#{variant}", (opts) =>
        @media.add new MediaItem(_.extend(opts, {type: variant}))

    @render()

  determineAutoloadStatus: ->
    stored = window.localStorage.getItem("autoloadMedia:#{@room}")
    return "unknown" if !stored
    return true if (stored == "true") or (stored == true)
    return false

  render: ->
    @$el.html @mediaLogTemplate()

  renderMedia: ->
    if @state.get('autoloadMedia') == true
      $body = @$el.find(".body")

      # O(n) in worst case, assuming document.contains is cheap
      for model in @media.models
        if !model.view.inDOM # if the view el is not already in the dom, then we'll add it
          if prev # push it in the right spot relative to its neighbours
            if prev.get('timestamp') > model.get('timestamp')
              prev.view.$el.after(model.view.el)
            else
              prev.view.$el.before(model.view.el)
          else # it's the first one we parse, simply push it in
            $body.append(model.view.el)
          model.view.inDOM = true
        prev = model

  clearMediaContents: ->
    @media.reset([])
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
    container = $(ev.currentTarget).closest(".media-item")
    $(ev.currentTarget).remove()
    container.find(".imageThumbnail").hide()
    container.find(".video").show()
    container.find(".media-buttons").addClass("collapsed")
