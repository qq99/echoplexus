Dice      = require('../../../src/server/extensions/dice.coffee').Dice

describe 'Dice', ->
  describe '#rollDie', ->
    it 'should give correct results for a variety of faces', ->
      i = 0
      while i < 1000
        assert.equal true, (Dice::rollDie(20) <= 20)
        i += 1

  describe '#parseDice', ->
    it 'assumes 1d20 on nonsensical input', ->
      assert.deepEqual {type: "1d20", nDies: 1, nFaces: 20}, Dice::parseDice("foobar")

    it 'should parse different types of dice correctly', ->
      assert.deepEqual {type: "5d10", nDies: 5, nFaces: 10}, Dice::parseDice("5d10")
      assert.deepEqual {type: "3d100", nDies: 3, nFaces: 100}, Dice::parseDice("3d100")
      assert.deepEqual {type: "1d20", nDies: 1, nFaces: 20}, Dice::parseDice("1d20")

  describe '#rollDice', ->
    it 'should correctly roll dice', ->
      dice = Dice::parseDice("2d10")

      i = 0
      while i < 1000
        result = Dice::rollDice(dice)
        assert.deepEqual dice, result.dice
        assert.equal true, result.sum <= (2*10)

        sumOfRolls = 0
        for roll in result.rolls
          sumOfRolls += roll

        assert.equal sumOfRolls, result.sum

        i += 1

  describe '#formatResult', ->
    it 'properly formats our dice roll result', ->
      mockResult =
        dice:
          type: "5d20"
          nDies: 5
          nFaces: 20
        rolls: [1,2,4,8,10]
        sum: 25

      assert.equal "rolled 5d20: 1 + 2 + 4 + 8 + 10 = 25", Dice::formatResult(mockResult)

    it 'formats results nicely when there was only a single die', ->
      mockResult =
        dice:
          type: "1d20"
          nDies: 1
          nFaces: 20
        rolls: [5]
        sum: 5

      assert.equal "rolled 1d20: 5", Dice::formatResult(mockResult)


