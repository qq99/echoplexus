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

  it 'accepts a list of custom whitelisted tags', ->
    html = "<p>this is a test<script>alert('hi')</script></p><video></video>"

    assert.equal "<p>this is a test</p>", @subject.sanitize(html)
    assert.equal "<p>this is a test</p><video></video>", @subject.sanitize(html, ["P", "VIDEO"])

  it 'accepts a list of custom whitelisted attributes', ->
    html = "<p title='wat'>u</p>"

    assert.equal "<p title=\"wat\">u</p>", @subject.sanitize(html, null, ["title"])

  it 'does not execute common XSS trickery', ->
    mock window, "alert"
    html = "';alert(String.fromCharCode(88,83,83))//';alert(String.fromCharCode(88,83,83))//\";alert(String.fromCharCode(88,83,83))//\";alert(String.fromCharCode(88,83,83))//--></SCRIPT>\">'><SCRIPT>alert(String.fromCharCode(88,83,83))</SCRIPT>"

    @subject.sanitize(html)

    assert !window.alert.called

  it 'does not execute scripts in img src', ->
    mock window, "alert"
    html = "<IMG SRC=\"javascript:alert('XSS');\">"

    @subject.sanitize(html, ["IMG"], ["src"])

    assert !window.alert.called
