require("../../events.js.coffee")()
require("../../utility.js.coffee")

module.exports.Log = class Log
  # this is: a persistent log if local storage is available, ELSE buncha noops

  LOG_VERSION: "0.0.2" # update if the server-side changes

  constructor: (opts) ->
    @latestID = -Infinity
    @log = [] # should always be sorted by timestamp
    @options =
      storage: localStorage
      namespace: "default"
      logMax: 256
    # extend defaults with any custom paramters
    _.extend @options, opts

    if Storage?
      version = @options.storage.getItem("logVersion:" + @options.namespace)
      if version isnt @LOG_VERSION
        @options.storage.setObj "log:#{@options.namespace}", null
        @options.storage.setItem "logVersion:#{@options.namespace}", @LOG_VERSION

      prevLog = @options.storage.getObj("log:#{@options.namespace}") or []
      if prevLog.length > @options.logMax # kill the previous log, getting too big
        prevLog = prevLog.slice(prevLog.length - @options.logMax)
        @options.storage.setObj "log:" + @options.namespace, prevLog
      @log = prevLog

    # events.on "getMissingIDs:#{@options.namespace}", (n) =>
    #   events.trigger "gotMissingIDs:#{@options.namespace}", @getMissingIDs(n)

  add: (obj) ->
    throw "Wrong object type for persistent log" if obj.get
    return if !Storage?
    return if obj.hasOwnProperty("log") and obj.log == false # don't store things we're explicitly ordered not to
    return if !obj.timestamp? # don't store things without a timestamp
    # keep track of highest so far
    @latestID = obj.mID  if obj.mID and obj.mID > @latestID

    # insert into the log
    @log.push obj

    # sort the log for consistency:
    @log = _.sortBy(@log, "timestamp")

    # cull the older log entries
    @log.shift()  if @log.length > @options.logMax

    # presist to localStorage:
    @options.storage.setObj "log:#{@options.namespace}", @log

  destroy: ->
    @log = []
    @options.storage.setObj "log:#{@options.namespace}", null

  empty: ->
    return if !Storage?
    @log.length is 0

  all: ->
    return if !Storage?
    @log

  latestIs: (id) ->
    return if !Storage?
    id = parseInt(id, 10)
    @latestID = id  if id > @latestID

  has: (byID) ->
    @known.indexOf(byID) >= 0

  knownIDs: ->
    return if !Storage?
    # compile a list of the message IDs we know about
    known = _.map @log, (obj) ->
      obj.mID
    known = _.without known, undefined
    known = _.uniq known
    @known = known # store it a while
    known

  getMessage: (byID) ->
    return if !Storage?
    start = @log.length - 1
    i = start

    while i >= 0
      return @log[i]  if @log[i].mID is byID
      i--
    null

  replaceMessage: (msg) ->
    return if !Storage?
    start = @log.length - 1
    i = start

    while i >= 0
      if @log[i].mID is msg.mID
        @log[i] = msg

        # presist to localStorage:
        @options.storage.setObj "log:#{@options.namespace}", @log
        return
      i--

  getListOfMissedMessages: ->
    return if !Storage?
    known = @knownIDs()
    clientLatest = known[known.length - 1] or -1
    missed = []
    sensibleMax = 50 # don't pull everything that we might have missed, just the most relevant range
    from = @latestID
    to = Math.max(from - sensibleMax, clientLatest + 1)

    # if the server is ahead of us
    if @latestID > clientLatest
      i = from

      while i >= to
        missed.push i
        i--
    else
      return null
    missed

  getMissingIDs: (N) -> # fills in any holes in our chat history
    return if !Storage?
    # compile a list of the message IDs we know about
    known = @knownIDs()

    # if we don't know about the server-sent latest ID, add it to the list:
    known.push @latestID + 1  if known[known.length - 1] isnt @latestID
    known.unshift -1 # a default element

    # compile a list of message IDs we know nothing about:
    holes = []
    i = known.length - 1

    while i > 0
      diff = known[i] - known[i - 1]
      j = 1

      while j < diff
        holes.push known[i] - j
        # only get N holes if we were requested to limit ourselves
        return holes  if N and (holes.length is N)
        j++
      i--
    holes
