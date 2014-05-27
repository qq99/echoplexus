_               = require("underscore")
uuid            = require("node-uuid")
config          = require("../server/config.coffee").Configuration
Client          = require("../client/client.js").ClientModel
redisC          = require("./RedisClient.coffee").RedisClient()
PermissionModel = require("./PermissionModel.coffee").ClientPermissionModel

module.exports.TokenBucket = class TokenBucket
  # from: http://stackoverflow.com/questions/667508/whats-a-good-rate-limiting-algorithm

  constructor: () ->
    @rate = config.chat.rate_limiting.rate # unit: # messages
    @per = config.chat.rate_limiting.per # unit: milliseconds
    @allowance = @rate # unit: # messages
    @last_check = Number(new Date()) # unit: milliseconds

  rateLimit: ->
    current = Number(new Date())
    time_passed = current - @last_check
    @last_check = current
    @allowance += time_passed * (@rate / @per)
    @allowance = @rate  if @allowance > @rate # throttle
    if @allowance < 1.0
      true # discard message, "true" to rate limiting
    else
      @allowance -= 1.0
      false # allow message, "false" to rate limiting

module.exports.ServerClient = class ServerClient extends Client

  names: ["Jack", "Jeannette", "Dennis", "Angelica", "Dale", "Mary", "William", "Mary", "Carl", "Benjamin", "Sue", "Mark", "Michael", "Robert", "Earl", "Kathy", "Elizabeth", "Son", "Eva", "Sherrie", "Robert", "Amy", "Allison", "Ann", "Tina", "Stephanie", "Judith", "Paul", "John", "Richard", "Margaret", "Marjorie", "Matthew", "Lincoln", "Gary", "Susan", "Marla", "Richard", "John", "Gertrude", "Craig", "Travis", "Marcus", "Michael", "Thomas", "Richard", "Julie", "Vincent", "Mary", "Jesus", "Angela", "Anthony", "Kelly", "Alexander", "Brian", "Richard", "Mattie", "Joshua", "Christopher", "Diane", "Cameron", "Lee", "Jeanne", "Jeremiah", "Christa", "Joseph", "Opal", "Cory", "Ashleigh", "Louis", "Georgia", "Frances", "Kevin", "Tara", "Mary", "Garry", "Frank", "Jay", "Tony", "Carol", "Danny", "Flora", "Jennifer", "Juanita", "Dale", "Mark", "Joe", "Mattie", "Jorge", "Jimmy", "Thersa", "Herbert", "Mae", "Sandra", "Loren", "Maria", "Clara", "Maria", "Allen", "Mary", "Beverly", "Jessica", "Robin", "John", "Shirley", "Stephanie", "Jacob", "Matthew", "Robert", "Alice", "Leann", "James", "Susan", "Stephen", "Michael", "Catrina", "Donald", "April", "Edna", "Joel", "Reggie", "Lee", "Julia", "Timothy", "David", "Samantha", "Richard", "Wesley", "Linda", "Donna", "Susann", "Kathryn", "James", "Francis", "Sarah", "Carlos", "Paul", "Melissa", "Jerry", "Kenneth", "Rebecca", "Allyson", "Tamera", "David", "Calvin", "Alvaro", "Richard", "Keith", "Matthew", "Andrew", "Reta", "Christopher", "Jeffery", "John", "Keith", "Guy", "Jeffrey", "Joe", "Robert", "Cynthia", "Frank", "Maria", "Matthew", "John", "Max", "Barbara", "Marcus", "Phyllis", "Matthew", "Vickie", "Shirley", "Aletha", "John", "Juan", "Jose", "Michael", "Carl", "Iva", "Katrina", "Frank", "Edward", "Daniel", "Lena", "Charlie", "Patrick", "Loretta", "Cynthia", "Rosalyn", "Brian", "Lawrence", "John", "Peter", "Florence", "Joseph", "Jeremy", "Susan", "Jessica", "James", "Douglas", "Dennis", "Rosario", "Terrance", "Lawrence", "Mark", "Doris", "Heidi", "Debra", "Nicole", "Shelly", "Edwin", "Marcos", "John", "Clifford", "Adele", "Jeff", "Shirley", "Cynthia", "Glen", "Evelyn", "Charlene", "Stephen", "Richard", "Debra", "Alisha", "Amanda", "Renee", "William", "Samuel", "Rachel", "Beau", "John", "Thomas", "Willie", "Tiffany", "Roger", "Jennifer", "Joshua", "Robert", "Jackie", "Dorothy", "Kim", "Judith", "Lori", "Dwight", "Paul", "Annette", "Kelly", "Thomas", "Betty", "Kenneth", "Robert", "Josie", "John", "Faye", "Wallace", "Alan", "Joseph", "Phillip", "Lisa", "Arlene", "Ina", "Claudine", "Rona", "Eloise", "Marie", "Kelly", "Dana", "Pat", "Doris", "Rebecca", "Steven", "Martin", "Frank", "Ann", "Chris", "Molly", "Christine", "Frances", "Ada", "Doug", "Hilary", "Damon", "Melissa", "Rosa", "Gloria", "Annie", "John", "Marion", "Elias", "Theodore", "Ellen", "Chet", "Kaye", "Patricia", "Paul", "Robin", "Steven", "Ronald", "Victor", "Hee", "Brian", "Leanna", "Elvie", "Robert", "Ernest", "Samuel", "Viola", "Yolanda", "Michael", "Charlotte", "Tim", "Jerry", "Juan", "Helen", "Milagros", "Paula", "Peter", "Gary", "Brian", "Jimmie", "Wilbur", "Vivian", "Randall", "Ramon", "Paul", "Marie", "Lenora", "Everett", "Benjamin", "Nathan", "Antonio", "Michael", "James", "Nelle", "Betty", "Frank", "Lenny", "Sammie", "Taylor", "Cynthia", "Suzanne", "Ashley", "Sharon", "Lela", "Laura", "Andrew", "William", "John", "James", "Mary", "Joan", "Enrique", "Thomas", "John", "Maria", "Stacey", "John", "Tammi", "Heidi", "Anita", "Joshua", "Anita", "Michael", "Peter", "Athena", "Celeste", "Margaret", "Leslie", "Sara", "Willie", "Yvette", "Deborah", "Jennifer", "Maria", "Anthony", "Christopher", "Angelique", "Sandra", "Paul", "Lora", "Robert", "Perry", "Gregory", "Margaret", "Gregory", "Paul", "Stephanie", "Tony", "Adrienne", "Jeffery", "Carol", "Megan", "Randy", "Kathrine", "Marcos", "Shelly", "Mabel", "James", "Joanne", "Emma"]

  initialize: ->
    _.bindAll.apply(_, [this].concat(_.functions(this)))

    randomName = @names[Math.floor( Math.random() * @names.length )]
    @set "nick", randomName

    @on "change:identified", (data) =>
      @loadMetadata()
      @setIdentityToken (err) =>
        throw err  if err
        @getPermissions()

    @on "change:encrypted_nick", (client, changed) =>
      # changed is either undefined, or an object representing {ciphertext,salt,iv}
      if changed # added a ciphernick
        @set "ciphernick", changed.ct
      else
        @unset "ciphernick"

    Client::initialize.apply this, arguments
    @set "permissions", new PermissionModel()

    # set a good global identifier
    @set "id", uuid.v4() if uuid?

    if (config?.chat?.rate_limiting?.enabled)
      @tokenBucket = new TokenBucket

  setIdentityToken: (callback) ->
    room = @get("room")
    nick = @get("nick")

    # check to see if a token already exists for the user
    redisC.hget "identity_token:#{room}", nick, (err, reply) =>
      callback err  if err
      unless reply # if not, make a new one
        token = uuid.v4()
        redisC.hset "identity_token:#{room}", nick, token, (err, reply) => # persist it
          throw err  if err
          @identity_token = token # store it on the client object
          callback null

      else
        token = reply
        @identity_token = token # store it on the client object
        callback null

  hasPermission: (permName) ->
    @get("permissions").get permName

  becomeChannelOwner: ->
    console.log @get "permissions"
    @get("permissions").upgradeToOperator()
    @set "operator", true # TODO: add a way to send client data on change events

  getPermissions: ->
    room = @get("room")
    nick = @get("nick")
    identity_token = @identity_token;

    console.log room, nick, identity_token

    return if !identity_token?

    redisC.hget "permissions:#{room}", "#{nick}:#{identity_token}", (err, reply) =>
      throw err if err
      if reply
        stored_permissions = JSON.parse(reply)
        @get("permissions").set stored_permissions

  persistPermissions: ->
    return if @get("identified")

    room = @get("room")
    nick = @get("nick")
    identity_token = @identity_token

    redisC.hset "permissions:#{room}", "#{nick}:#{identity_token}", JSON.stringify(@get("permissions").toJSON())

  metadataToArray: ->
    data = []
    _.each @supported_metadata, (field) =>
      data.push field
      data.push @get(field)

    data

  saveMetadata: ->
    if @get("identified")
      room = @get("room")
      nick = @get("nick")
      data = @metadataToArray()
      redisC.hmset "users:room:#{nick}", data, (err, reply) ->
        throw err  if err
        callback null

  loadMetadata: ->
    if @get("identified")
      room = @get("room")
      nick = @get("nick")
      fields = {}
      redisC.hmget "users:room:#{nick}", @supported_metadata, (err, reply) =>
        throw err  if err

        # console.log("metadata:", reply);
        i = 0

        while i < reply.length
          fields[@supported_metadata[i]] = reply[i]
          i++

        # console.log(fields);
        @set fields,
          trigger: true

        reply # just in case
