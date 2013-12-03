regexes      = require('../../src/client/regex.js.coffee').REGEXES

image_samples = [
  "http://example.com/my-img.png",
  "http://example.com/my%20img.png",
  "http://example.com/my_img.png#?from=whatever&query=whaaat"
]
youtube_samples = [
  "http://www.youtube.com/watch?v=08MFfj_ZXWU",
  "http://www.youtube.com/watch?feature=player_detailpage&v=08MFfj_ZXWU#t=10"
]
all_other_url_samples = [
  "http://anthonycameron.com",
  "https://chat.echoplex.us",
  "https://echoplex.us",
  "http://www.google.ca"
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
