# object: a persistent log if local storage is available ELSE noops

module.exports.Log = class Log

  LOG_VERSION: "0.0.2" # update if the server-side changes

  constructor: (opts) ->
    @latestID = -Infinity
    @log = [] # should always be sorted by timestamp
    @options =
      namespace: "default"
      logMax: 256
    # extend defaults with any custom paramters
    _.extend @options, opts

    if window.Storage?
      version = window.localStorage.getItem("logVersion:" + @options.namespace)
      if typeof version is "undefined" or version is null or version isnt LOG_VERSION
        window.localStorage.setObj "log:" + @options.namespace, null
        window.localStorage.setItem "logVersion:" + @options.namespace, LOG_VERSION
      prevLog = window.localStorage.getObj("log:" + @options.namespace) or []
      if prevLog.length > @options.logMax # kill the previous log, getting too big
        prevLog = prevLog.slice(prevLog.length - @options.logMax)
        window.localStorage.setObj "log:" + @options.namespace, prevLog
      @log = prevLog

  add: (obj) ->
    return if !window.Storage?
    return  if obj.log and obj.log is false # don't store things we're explicitly ordered not to
    return  if obj.timestamp is false # don't store things without a timestamp
    # keep track of highest so far
    @latestID = obj.mID  if obj.mID and obj.mID > @latestID

    # insert into the log
    @log.push obj

    # sort the log for consistency:
    @log = _.sortBy(log, "timestamp")

    # cull the older log entries
    @log.unshift()  if @log.length > options.logMax

    # presist to localStorage:
    window.localStorage.setObj "log:#{@options.names}", @log

  destroy: ->
    log = []
    window.localStorage.setObj "log:" + options.namespace, null

  empty: ->
    return if !window.Storage?
    log.length is 0

  all: ->
    return if !window.Storage?
    log

  latestIs: (id) ->
    return if !window.Storage?
    id = parseInt(id, 10)
    latestID = id  if id > latestID

  knownIDs: ->
    return if !window.Storage?
    # compile a list of the message IDs we know about
    known = _.without(_.map(log, (obj) ->
      obj.mID
    ), `undefined`)
    known

  getMessage: (byID) ->
    return if !window.Storage?
    start = log.length - 1
    i = start

    while i > 0
      return log[i]  if log[i].mID is byID
      i--
    null

  replaceMessage: (msg) ->
    return if !window.Storage?
    start = log.length - 1
    i = start

    while i > 0
      if log[i].mID is msg.mID
        log[i] = msg

        # presist to localStorage:
        window.localStorage.setObj "log:" + options.namespace, log
        return
      i--

  getListOfMissedMessages: ->
    return if !window.Storage?
    known = @knownIDs()
    clientLatest = known[known.length - 1] or -1
    missed = []
    sensibleMax = 50 # don't pull everything that we might have missed, just the most relevant range
    from = latestID
    to = Math.max(latestID - sensibleMax, clientLatest + 1)

    # if the server is ahead of us
    if latestID > clientLatest
      i = from

      while i >= to
        missed.push i
        i--
    else
      return null
    missed

  getMissingIDs: (N) -> # fills in any holes in our chat history
    return if !window.Storage?
    # compile a list of the message IDs we know about
    known = @knownIDs()

    # if we don't know about the server-sent latest ID, add it to the list:
    known.push latestID + 1  if known[known.length - 1] isnt latestID
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
