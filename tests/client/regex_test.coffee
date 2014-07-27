regexes      = require('../../src/client/regex.js.coffee').REGEXES

image_samples = [
  "http://example.com/my-img.png"
  "http://example.com/my%20img.png"
  "http://www.example.com/my.png?yo=lo"
  "http://example.com/my_img.png#?from=whatever&query=whaaat"
]
youtube_samples = [
  "http://www.youtube.com/watch?v=08MFfj_ZXWU"
  "http://www.youtube.com/watch?feature=player_detailpage&v=08MFfj_ZXWU#t=10"
]
all_other_url_samples = [
  "http://anthonycameron.com"
  "https://chat.echoplex.us"
  "https://echoplex.us"
  "https://echoplex.us#foobar"
  "http://www.google.ca"
  "https://www.mail-archive.com/tor-talk@lists.torproject.org"
]

partialMatch = (sampleSet, regex) ->
  for sample in sampleSet
    match = sample.match(regex)[0]
    index = match.indexOf(sample)
    index = sample.indexOf(match) if index is -1
    assert.notEqual -1, index

perfectMatch = (sampleSet, regex) ->
  for sample in sampleSet
    assert.equal sample, sample.match(regex)[0]

noMatch = (sampleSet, regex) ->
  for sample in sampleSet
    assert.equal null, sample.match(regex)

assertMatches = (string, regex) ->
  assert string.match(regex)?.length

assertNoMatches = (string, regex) ->
  assert.equal null, string.match(regex)

describe 'Regexes', ->
  describe 'urls.image', ->
    it 'matches images properly', ->
      perfectMatch(image_samples, regexes.urls.image)

    it 'does not match non-images', ->
      noMatch(all_other_url_samples, regexes.urls.image)
      noMatch(youtube_samples, regexes.urls.image)

  describe 'urls.youtube', ->
    it 'matches images properly', ->
      partialMatch(youtube_samples, regexes.urls.youtube) # should be perfect match?

    it 'does not match non-youtube', ->
      noMatch(all_other_url_samples, regexes.urls.youtube)
      noMatch(image_samples, regexes.urls.youtube)

  describe 'urls.all_others', ->
    it 'matches all other urls properly', ->
      perfectMatch(all_other_url_samples, regexes.urls.all_others)
      perfectMatch(image_samples, regexes.urls.all_others)
      perfectMatch(youtube_samples, regexes.urls.all_others)

  describe 'users', ->
    describe 'mentions', ->
      it 'matches @nick', ->
        body = "hey @nick what's up!"
        assertMatches("hey @nick what's up", regexes.users.mentions)

  describe 'commands', ->
    describe 'nick', ->
      beforeEach ->
        @re = regexes.commands.nick
      it 'matches /nick', ->
        assertMatches("/nick Anon", @re)
      it 'matches /n', ->
        assertMatches("/n Anon", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches("type /nick to set your nick", @re)

    describe 'topic', ->
      beforeEach ->
        @re = regexes.commands.topic
      it 'matches /topic', ->
        assertMatches("/topic test", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /topic test", @re)

    describe 'broadcast', ->
      beforeEach ->
        @re = regexes.commands.broadcast
      it 'matches /broadcast', ->
        assertMatches("/broadcast hi all", @re)
      it 'matches /bc', ->
        assertMatches("/bc hi all", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /broadcast test", @re)

    describe 'private', ->
      beforeEach ->
        @re = regexes.commands.private
      it 'matches /private', ->
        assertMatches("/private secret", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /private secret", @re)

    describe 'public', ->
      beforeEach ->
        @re = regexes.commands.public
      it 'matches /public', ->
        assertMatches("/public", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /public", @re)

    describe 'help', ->
      beforeEach ->
        @re = regexes.commands.help
      it 'matches /help', ->
        assertMatches("/help", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches("so /help", @re)

    describe 'private_message', ->
      beforeEach ->
        @re = regexes.commands.private_message
      it 'matches /pm', ->
        assertMatches("/pm @Anon hi", @re)
      it 'matches /whisper', ->
        assertMatches("/pm @Anon hi", @re)
      it 'matches /w', ->
        assertMatches("/w @Anon hi", @re)
      it 'matches /tell', ->
        assertMatches("/tell @Anon hi", @re)
      it 'matches /t', ->
        assertMatches("/t @Anon hi", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /t @Anon hi", @re)

    describe 'join', ->
      beforeEach ->
        @re = regexes.commands.join
      it 'matches /join', ->
        assertMatches("/join channelname", @re)
      it 'matches /j', ->
        assertMatches("/join nsfw", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /join girlsgonewild", @re)

    describe 'leave', ->
      beforeEach ->
        @re = regexes.commands.leave
      it 'matches /leave', ->
        assertMatches("/leave", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /leave", @re)

    describe 'pull_logs', ->
      beforeEach ->
        @re = regexes.commands.pull_logs
      it 'matches /pull', ->
        assertMatches("/pull 10", @re)
      it 'matches /p', ->
        assertMatches("/p 20", @re)
      it 'matches /sync', ->
        assertMatches("/sync 40", @re)
      it 'matches /s', ->
        assertMatches("/s 30", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /s 30", @re)

    describe 'set_color', ->
      beforeEach ->
        @re = regexes.commands.set_color
      it 'matches /color', ->
        assertMatches("/color #fff", @re)
      it 'matches /c', ->
        assertMatches("/c #ABCDEF", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /c #333", @re)

    describe 'edit', ->
      beforeEach ->
        @re = regexes.commands.edit
      it 'matches /edit when a #[messageID] is supplied', ->
        assertMatches("/edit #538 new text", @re)
      it 'does not match /edit when a #[messageID] is not supplied', ->
        assertNoMatches("/edit hi", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches("  /edit #1 hi", @re)

    describe 'chown', ->
      beforeEach ->
        @re = regexes.commands.chown
      it 'matches /chown', ->
        assertMatches("/chown password", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /chown password", @re)

    describe 'chmod', ->
      beforeEach ->
        @re = regexes.commands.chmod
      it 'matches /chmod', ->
        assertMatches("/chmod +canSetTopic", @re)
      it 'matches /chmod with username', ->
        assertMatches("/chmod Alice +canSetTopic", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /chmod +canSetTopic", @re)

    describe 'reply', ->
      beforeEach ->
        @re = regexes.commands.reply
      it 'matches >>12345', ->
        assertMatches(">>111", @re)
        assertMatches(">>0", @re)
      it 'does not match >> without any message ID', ->
        assertNoMatches(">> hi how are ya", @re)
      it 'matches anywhere in the string', ->
        assertMatches("I think >>55 is completely wrong.", @re)

    describe 'roll', ->
      beforeEach ->
        @re = regexes.commands.roll
      it 'matches /roll', ->
        assertMatches("/roll", @re)
      it 'matches /roll with a dice', ->
        assertMatches("/roll 1d20", @re)
        assertMatches("/roll 3d9", @re)
      it 'does not match in the middle of a string', ->
        assertNoMatches(" /roll 5d50", @re)

  describe 'colors', ->
    describe 'hex', ->
      beforeEach ->
        @re = regexes.colors.hex
      it 'matches 6char hex', ->
        assertMatches("#1F3D9A", @re)
        assertMatches("F0a3b3", @re)
      it 'matches 3char hex', ->
        assertMatches("#333", @re)
        assertMatches("01F", @re)


