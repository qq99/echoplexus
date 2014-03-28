# consider these persistent options
# we use a cookie for these since they're small and more compatible
module.exports.Options = class Options

  defaults:
    show_mewl                          : true
    suppress_join                      : true
    highlight_mine                     : true
    prefer_24hr_clock                  : true
    suppress_client                    : true
    show_OS_notifications              : true
    suppress_identity_acknowledgements : true
    join_default_channel               : true
    auto_scroll                        : true
    play_notification_sounds           : false

  updateOption: (value, option) ->
    $option = $("#" + option)

    valueFromCookie = $.cookie(option) # check if the options are in the cookie, if so update the value
    value = JSON.parse(valueFromCookie) if valueFromCookie

    window.OPTIONS[option] = value
    if value
      $("body").addClass option
      $option.attr "checked", "checked"
    else
      $("body").removeClass option
      $option.removeAttr "checked"

    # bind events to the click of the element of the same ID as the option's key
    $option.on "click", ->
      $.cookie option, $(this).prop("checked"), window.COOKIE_OPTIONS
      OPTIONS[option] = not OPTIONS[option]
      if OPTIONS[option]
        $("body").addClass option
      else
        $("body").removeClass option

  updateAllOptions: () ->
    _.each window.OPTIONS, @updateOption

  constructor: (@options) ->
    if !@options
      @options = @defaults

    window.OPTIONS = @options
    @updateAllOptions()
