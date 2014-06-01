{Adapter,TextMessage} = require 'hubot'
sio                   = require 'socket.io-client'

class Echoplexus extends Adapter
  #constructor: ->
  #super

  send: (params, strings...) ->

  reply: (params, strings...) ->
    user = @userFromParams(params)
    strings.forEach (str) =>
      @send params, "@#{user.name}: #{str}"

  userFromParams: (params) ->
    # hubot < 2.4.2: params = user
    # hubot >= 2.4.2: params = {user: user, ...}
    #if params.user then params.user else params

  flowFromParams: (params) ->
    #@flowsByParametrizedNames[params.room]

  userFromId: (id, data) ->
    # hubot < 2.5.0: @userForId
    # hubot >=2.5.0: @robot.brain.userForId
    #@robot.brain?.userForId?(id, data) || @userForId(id, data)

  changeUserNick: (id, newNick) ->
    # if id of @robot.brain.data.users
    #   @robot.brain.data.users[id].name = newNick

  connect: ->
    socket = sio.connect "127.0.0.1:8080/chat",
      "connect timeout": 1000
      "reconnect": true
      "reconnection delay": 2000
      "max reconnection attempts": 1000

    socket.emit "subscribe", 
      room: "/"
    # ids = (flow.id for flow in @flows)
    # @stream = @bot.stream(ids, active: 'idle', user: 1)
    # @stream.on 'message', (message) =>
    #   if message.event == 'user-edit'
    #     @changeUserNick(message.content.user.id, message.content.user.nick)
    #   return unless message.event in ['message', 'comment']
    #   if message.event == 'message'
    #     messageId = message.id
    #   else
    #     # For comments the parent message id is embedded in an 'influx' tag
    #     if message.tags
    #       influxTag = do ->
    #         for tag in message.tags
    #           return tag if /^influx:/.test tag
    #       messageId = (influxTag.split ':', 2)[1] if influxTag

    #   author =
    #     id: message.user
    #     name: @userFromId(message.user).name
    #     flow: message.flow

    #   author['message'] = messageId if messageId

    #   return if @robot.name.toLowerCase() == author.name.toLowerCase()

    #   msg = if message.event == 'comment' then message.content.text else message.content

    #   # Reformat leading @mention name to be like "name: message" which is
    #   # what hubot expects. Add bot name with private messages if not already given.
    #   botPrefix = "#{@robot.name}: "
    #   regex = new RegExp("^@#{@robot.name}(,|\\b)", "i")
    #   hubotMsg = msg.replace(regex, botPrefix)
    #   if !message.flow && !hubotMsg.match(new RegExp("^#{@robot.name}", "i"))
    #     hubotMsg = botPrefix + hubotMsg
    #   @receive new TextMessage(author, hubotMsg)

  run: ->
    # @login_email    = process.env.HUBOT_FLOWDOCK_LOGIN_EMAIL
    # @login_password = process.env.HUBOT_FLOWDOCK_LOGIN_PASSWORD
    # unless @login_email && @login_password
    #   console.error "ERROR: No credentials in environment variables HUBOT_FLOWDOCK_LOGIN_EMAIL and HUBOT_FLOWDOCK_LOGIN_PASSWORD"
    #   @emit "error", "No credentials"

    # @bot = new flowdock.Session(@login_email, @login_password)
    # @bot.on "error", (e) =>
    #   if e == 401
    #     console.error "Could not authenticate, please check your credentials"
    #   else
    #     console.error "Unexpected error in creating Flowdock session: #{e}"
    #   @emit e

    # @bot.flows (flows) =>
    #   @flows = flows
    #   @flowsByParametrizedNames = {}
    #   for flow in flows
    #     @flowsByParametrizedNames["#{flow.organization.parameterized_name}/#{flow.parameterized_name}"] = flow
    #     for user in flow.users
    #       data =
    #         id: user.id
    #         name: user.nick
    #       savedUser = @userFromId user.id, data
    #       if (savedUser.name != data.name)
    #         @changeUserNick(savedUser.id, data.name)
    #   @connect()

    #@bot

    #@emit 'connected'

exports.use = (robot) ->
  new Echoplexus robot