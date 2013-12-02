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

    it 'will cull older log entries if it exceeds the user defined threshold', ->
      @subject.add
        body: 'hi'
        timestamp: 5
      @subject.add
        body: 'there'
        timestamp: 4

      assert.deepEqual [{timestamp:1},{timestamp:2},{timestamp:3},{body:'there', timestamp: 4},{body:'hi',timestamp: 5}], @subject.log
