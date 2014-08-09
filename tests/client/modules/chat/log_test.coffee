Log       = require('../../../../src/client/modules/chat/Log.js.coffee').Log

describe 'Log', ->
  beforeEach ->
    Log.prototype.LOG_VERSION = '0'
    @store = {}
    @fakeStorage =
      getItem: (key) =>
        @store[key]
      setItem: (key, value) =>
        @store[key] = value
      clear: =>
        @store = {}
      setObj: (key, obj) =>
        @store[key] = JSON.stringify(obj)
      getObj: (key) =>
        JSON.parse @store[key]

  describe 'constructor', ->
    it 'accepts arguments', ->
      @subject = new Log({namespace: '/', logMax: 512})
      assert.equal '/', @subject.options.namespace
      assert.equal 512, @subject.options.logMax

    it 'sets the log version on initialization if it does not already exist', ->
      spy(@fakeStorage, 'getItem')
      spy(@fakeStorage, 'setItem')
      spy(@fakeStorage, 'setObj')

      Log.prototype.LOG_VERSION = '5.5.5'
      @subject = new Log({namespace: '/', storage: @fakeStorage})

      assert @fakeStorage.getItem.calledWith("logVersion:/")
      assert @fakeStorage.setObj.calledWith("log:/", null)
      assert @fakeStorage.setItem.calledWith("logVersion:/", "5.5.5")

    it 'clears anything in the previous logs if the stored log version does not match that on the prototype', ->
      spy(@fakeStorage, 'getObj')
      @fakeStorage.setObj('log:/', [1,2,3,4,5])
      @fakeStorage.setItem('logVersion:/', 'not gonna match anything')

      @subject = new Log({namespace: '/', storage: @fakeStorage})

      assert @fakeStorage.getObj.calledWith("log:/")
      assert.deepEqual [], @subject.log

    it 'gets an empty array for @log', ->
      spy(@fakeStorage, 'getObj')

      @subject = new Log({namespace: '/test', storage: @fakeStorage})

      assert @fakeStorage.getObj.calledWith("log:/test")
      assert.deepEqual [], @subject.log

    it 'succesfully gets the previous @log array if it existed', ->
      @fakeStorage.setObj('log:/', [1,2,3,4,5])
      @fakeStorage.setItem('logVersion:/', '0')

      spy(@fakeStorage, 'getObj')

      @subject = new Log({namespace: '/', storage: @fakeStorage})

      assert @fakeStorage.getObj.calledWith("log:/")
      assert.deepEqual [1,2,3,4,5], @subject.log

    it 'will truncate the data stored in the log if we are above a user defined threshold', ->
      @fakeStorage.setObj('log:/', [1,2,3,4,5])
      @fakeStorage.setItem('logVersion:/', '0')

      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 2})
      assert.deepEqual [4,5], @subject.log

  describe '#add', ->
    beforeEach ->
      @initialSet = [{timestamp:0},{timestamp:1},{timestamp:2},{timestamp:3}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'will not add objects that are explicitly set to log=false', ->
      @subject.add
        body: 'hi'
        timestamp: 0
        log: false

      assert.deepEqual @initialSet, @subject.log

    it 'will not add objects without a timestamp', ->
      @subject.add
        body: 'hi'

      assert.deepEqual @initialSet, @subject.log

    it 'will sort log entries by timestamp upon being added', ->
      @subject.add
        timestamp: 1.5

      assert.deepEqual [{timestamp:0},{timestamp:1},{timestamp:1.5},{timestamp:2},{timestamp:3}], @subject.log

    it 'will persist to localStorage', ->
      spy(@fakeStorage, 'setObj')
      @subject.add
        timestamp: 1.5

      assert @fakeStorage.setObj.calledOnce
      assert @fakeStorage.setObj.calledWith('log:/', [{timestamp:0},{timestamp:1},{timestamp:1.5},{timestamp:2},{timestamp:3}])

  describe "#destroy", ->
    beforeEach ->
      @initialSet = [{timestamp:0},{timestamp:1},{timestamp:2},{timestamp:3}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'should destroy the log from localStorage', ->
      spy(@fakeStorage, 'setObj')

      @subject.destroy()

      assert @fakeStorage.setObj.calledWith('log:/', null)

    it 'should destroy log from working memory', ->
      @subject.destroy()
      assert.deepEqual [], @subject.log

  describe "#empty", ->
    beforeEach ->
      @initialSet = [{timestamp:0},{timestamp:1},{timestamp:2},{timestamp:3}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'returns false if there are items', ->
      assert.equal false, @subject.empty()

    it 'returns true if there are no items', ->
      @subject.destroy()
      assert.equal true, @subject.empty()

  describe "#all", ->
    beforeEach ->
      @initialSet = [1,2,3]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'is an alias for .log', ->
      assert.deepEqual @subject.log, @subject.all()

  describe "#latestIs", ->
    beforeEach ->
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'sets the mID of the latest message', ->
      @subject.latestIs(5)
      assert 5, @subject.latestID
    it 'sets the mID of the latest message, if it is greater than the current latest', ->
      @subject.latestIs(10)
      assert 10, @subject.latestID

      @subject.latestIs(20)
      assert 20, @subject.latestID

      @subject.latestIs(0)
      assert 20, @subject.latestID

  describe "#knownIDs", ->
    beforeEach ->
      @initialSet = [{mID: 0},{},{mID: 5}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'returns an array of all known mIDs, when they exist', ->
      assert.deepEqual [0,5], @subject.knownIDs()
    it 'should not die if there is nothing in the log', ->
      @fakeStorage.setObj('log:/', [])
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})
      assert.deepEqual [], @subject.knownIDs()

    it 'returns a list of all mIDs we know about, after adding with .add', ->
      @fakeStorage.setObj('log:/', [])
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

      for i in _.range(100, 95, -1)
        @subject.add({mID: i, timestamp: Number(new Date())})

      assert.deepEqual [100,99,98,97,96], @subject.knownIDs()

  describe "#getMessage", ->
    beforeEach ->
      @initialSet = [{mID: 0, body: 'hi'},{},{mID: 5, body: 'there'}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'should allow us to query the structure for a particular item by mID', ->
      assert.deepEqual {mID: 0, body: 'hi'}, @subject.getMessage(0)
      assert.deepEqual {mID: 5, body: 'there'}, @subject.getMessage(5)
    it 'returns null if there was no message by that mID', ->
      assert.equal null, @subject.getMessage(999)

  describe '#replaceMessage', ->
    beforeEach ->
      @initialSet = [{mID: 0, body: 'hi'},{},{mID: 5, body: 'there'}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'will replace a message by mID', ->
      @subject.replaceMessage({mID:0, body:'yo'})
      assert.deepEqual {mID: 0, body: 'yo'}, @subject.getMessage(0)
      @subject.replaceMessage({mID:5, body:'yo'})
      assert.deepEqual {mID: 5, body: 'yo'}, @subject.getMessage(5)
    it 'does nothing if the mID never existed', ->
      @subject.replaceMessage({mID:999, body:'ghost'})
      assert.deepEqual @initialSet, @subject.log

  describe '#getMissedSinceLastTime', ->
    beforeEach ->
      @initialSet = [{mID: 0, body: 'hi'},{},{mID: 5, body: 'there'}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'will give us a list of all IDs higher than our latestID when the server is ahead of us', ->
      @subject.latestID = 10
      assert.deepEqual [10, 9, 8, 7, 6], @subject.getMissedSinceLastTime()

      @subject.latestID = 8
      assert.deepEqual [8, 7, 6], @subject.getMissedSinceLastTime()

    it 'will return null if the server is not ahead of us', ->
      @subject.latestID = 5
      assert.equal null, @subject.getMissedSinceLastTime()

  describe '#getMissingIDs', ->
    beforeEach ->
      @initialSet = [{mID: 0, body: 'hi'},{},{mID: 5, body: 'there'}]
      @fakeStorage.setObj('log:/', @initialSet)
      @fakeStorage.setItem('logVersion:/', '0')
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

    it 'returns a list of mIDs missing from our chat history, up til the server latest mID', ->
      @subject.latestID = 10
      assert.deepEqual [10, 9, 8, 7, 6, 4, 3, 2, 1], @subject.getMissingIDs()

    it 'returns a list of mIDS missing from our chat history when the server is not ahead of us', ->
      @subject.latestID = 5
      assert.deepEqual [4,3,2,1], @subject.getMissingIDs()

    it 'works properly on a very hole-y log', ->
      @initialSet = [{mID: 4, body: 'hi'},{},{mID: 8, body: 'there'}]
      @fakeStorage.setObj('log:/', @initialSet)
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

      @subject.latestID = 10
      assert.deepEqual [10,9,7,6,5,3,2,1,0], @subject.getMissingIDs()

    it 'takes a parameter requesting how many missing IDs to return, returns correct value independent of the logMax storage value', ->
      @fakeStorage.setObj('log:/', [])
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

      for id in _.range(100, 80, -1) # adds 100..81 to log
        @subject.add({mID: id, timestamp: Number(new Date())})

      assert.deepEqual 20, @subject.knownIDs().length
      assert.deepEqual [80, 79, 78, 77, 76], @subject.getMissingIDs(5)

    it 'with no parameter is supplied, it defaults to a sensible max of 50', ->
      @fakeStorage.setObj('log:/', [])
      @subject = new Log({namespace: '/', storage: @fakeStorage, logMax: 5})

      for id in _.range(100, 80, -1) # adds 100..81 to log
        @subject.add({mID: id, timestamp: Number(new Date())})

      assert.deepEqual 20, @subject.knownIDs().length
      assert.deepEqual 50, @subject.getMissingIDs().length
