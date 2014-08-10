ChatMessageModel = require('../../../../src/client/modules/chat/ChatMessageModel.js.coffee').ChatMessage

describe 'ChatMessageModel', ->
  stub(ChatMessageModel.prototype, "initialize")
  describe 'basic rendering pipeline', ->
    it 'does nothing special for a simple body content', ->
      @subject = new ChatMessageModel
        body: "This is a test"

      @subject.format_body()

      assert.equal "This is a test", @subject.get("formatted_body")

    it 'converts links into hyperlinks', ->
      @subject = new ChatMessageModel
        body: "some URL http://google.ca"

      @subject.format_body()

      assert.equal 'some URL <a rel="noreferrer" target="_blank" href="http://google.ca">http://google.ca</a>', @subject.get("formatted_body")

    it 'supports body with mentions and links with @ in them', ->
      @subject = new ChatMessageModel
        body: "@qq99 here's a link for you https://echoplex.us@foo.com @qq99"

      @subject.format_body()

      assert.equal '<span class="mention">@qq99</span> here&#x27;s a link for you <a rel="noreferrer" target="_blank" href="https://echoplex.us@foo.com">https://echoplex.us@foo.com</a><span class="mention"> @qq99</span>', @subject.get("formatted_body")

    it 'renders quotations properly', ->
      @subject = new ChatMessageModel
        body: ">>99 I agree >>100 I disagree"
      @subject.room = "/foo"

      @subject.format_body()

      assert.equal '<a rel="99" class="quotation" href="#/foo99">&gt;&gt;99</a> I agree <a rel="100" class="quotation" href="#/foo100">&gt;&gt;100</a> I disagree', @subject.get("formatted_body")

    it 'defaults to empty array for references', ->
      @subject = new ChatMessageModel
      assert.deepEqual [], @subject.get("references")

    it 'computes its list of references on render', ->
      @subject = new ChatMessageModel
        body: ">>99 I agree >>100 I disagree"
      @subject.room = "/foo"

      @subject.format_body()
      assert.deepEqual [99, 100], @subject.get("references")
