HTMLSanitizer      = require('../../src/client/utility.js.coffee').HTMLSanitizer

describe 'HTMLSanitizer', ->
  beforeEach ->
    @subject = new HTMLSanitizer

  it 'strips out unwanted attributes', ->
    html = "<a href=\"/\" onerror=\"alert('hi')\">XSS</a>"

    assert.equal '<a href="/">XSS</a>', @subject.sanitize(html)

  it 'strips out unwanted tags', ->
    html = "<p>this is a test<script>alert('hi')</script></p>"

    assert.equal "<p>this is a test</p>", @subject.sanitize(html)
