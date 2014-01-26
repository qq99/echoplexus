versionStringToNumber = require('../../src/client/utility.js.coffee').versionStringToNumber

describe 'versionStringToNumber()', ->

  it 'correctly interprets the string as a number', ->
    assert.equal 1, versionStringToNumber("0.0.0r1")
    assert.equal 230, versionStringToNumber("0.2.3r0")
    assert.equal 231, versionStringToNumber("0.2.3r1")
    assert.equal 1350, versionStringToNumber("1.3.5r0")

