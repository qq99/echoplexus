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

perfectMatch = (sampleSet, regex) ->
  for sample in sampleSet
    assert.equal sample, sample.match(regex)[0]

noMatch = (sampleSet, regex) ->
  for sample in sampleSet
    assert.equal null, sample.match(regex)

describe 'Regexes', ->
  describe 'urls.image', ->
    it 'matches images properly', ->
      perfectMatch(image_samples, regexes.urls.image)

    it 'does not match non-images', ->
      noMatch(all_other_url_samples, regexes.urls.image)
      noMatch(youtube_samples, regexes.urls.image)
