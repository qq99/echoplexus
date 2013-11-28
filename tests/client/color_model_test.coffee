client      = require('../../src/client/client.js.coffee')
ColorModel  = client.ColorModel

describe 'Client.ColorModel', ->
  beforeEach ->
    @subject = new ColorModel
      r: 111
      g: 222
      b: 94

  describe 'constructors', ->
    it 'if passed parameters, should initialize with those parameters', ->
      expect(@subject.get("r")).to.equal 111
      expect(@subject.get("g")).to.equal 222
      expect(@subject.get("b")).to.equal 94

    it 'if passed no parameters, it should randomly create a color', ->
      mathRandom = spy Math, 'random'

      @subject = new ColorModel
      assert (mathRandom.callCount >= 3), "at least 3 random calls for RGB"

  describe '#setFromHex', ->
    it 'should properly convert and set from 6-hex string to RGB', ->
      @subject.parse('#FF000A')
      assert.equal 255, @subject.get('r')
      assert.equal 0, @subject.get('g')
      assert.equal 10, @subject.get('b')

    it 'should properly convert and set from 3-hex string to RGB', ->
      @subject.parse('#666')
      assert.equal 102, @subject.get('r')
      assert.equal 102, @subject.get('g')
      assert.equal 102, @subject.get('b')

      @subject.parse('#ABC')
      assert.equal 171, @subject.get('r')
      assert.equal 202, @subject.get('g')
      assert.equal 188, @subject.get('b')

    it 'should not accept other CSS color formats (yet)', ->
      cb = stub()

      @subject.parse('rgba(0,0,0,0.5)', cb)

      assert cb.called, "It didn't call the callback"
      assert cb.neverCalledWith(null), "It didn't call the callback with an error"

  describe '#toRGB', ->
    it 'should convert to rgb() CSS format correctly', ->
      assert.equal 'rgb(111,222,94)', @subject.toRGB()
