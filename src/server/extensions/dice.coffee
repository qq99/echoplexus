module.exports.Dice = class Dice
  rollDie: (nFaces) ->
    1 + Math.floor(Math.random()*nFaces)

  parseDice: (diceString) ->
    # converts, e.g., '5d20' into the dice representation
    # interprets non-matches as '1d20'
    type = "1d20"
    nDies = "1"
    nFaces = "20"

    matches = diceString.match(/(\d+)d(\d+)/) # '50d209' matches = ['50d209', '50', '209']
    if matches?.length == 3
      type = matches[0]
      nDies = matches[1]
      nFaces = matches[2]

    dice =
      type: type
      nDies: parseInt(nDies, 10)
      nFaces: parseInt(nFaces, 10)

  rollDice: (dice) ->
    results = []

    sum = 0; i = 0
    while i < dice.nDies
      roll = @rollDie(dice.nFaces)
      results.push roll
      sum += roll
      i++

    result =
      dice: dice
      sum: sum
      rolls: results

  parseAndRollDice: (diceString) ->
    @rollDice @parseDice diceString

  formatResult: (diceResult) ->
    if diceResult.rolls.length > 1
      visualSum = diceResult.rolls.join(" + ")
      "rolled #{diceResult.dice.type}: #{visualSum} = #{diceResult.sum}"
    else
      "rolled #{diceResult.dice.type}: #{diceResult.sum}"
