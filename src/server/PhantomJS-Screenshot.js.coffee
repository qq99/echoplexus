# usage: phantomjs this_file url file.out [width height]
page = require("webpage").create()
system = require("system")
w = 1024
h = 768
address = undefined
output = undefined
size = undefined
address = system.args[1]
output = system.args[2]
page.viewportSize =
  width: w
  height: h

page.clipRect =
  width: w
  height: h

if system.args.length is 5 # if a resolution was supplied
  w = system.args[3]
  h = system.args[4]
  page.viewportSize =
    width: w
    height: h

  page.clipRect =
    top: 0
    left: 0
    width: w
    height: h

try
  page.open address, (status) ->
    if status isnt "success"
      console.log "Unable to load the address!"
    else
      window.setTimeout (-> # have to give phantom time to start up
        extracted_information = title: page.title

        # extract some data from the page:
        data = page.evaluate(->
          firstParagraph = document.getElementsByTagName("p")
          if firstParagraph and firstParagraph.length
            firstParagraph = firstParagraph[0].textContent
            excerpt: document.getElementsByTagName("p")[0].textContent
          else
            excerpt: ""
        )
        if typeof data.excerpt isnt "undefined"
          data.excerpt = data.excerpt.trim().replace(/\n/g, "")
          data.excerpt = data.excerpt.substring(0, 1024) + "..."  if data.excerpt.length > 1024
          extracted_information.excerpt = data.excerpt
        console.log JSON.stringify(extracted_information)
        page.render output
        phantom.exit()
      ), 200
catch e
  console.log "Screenshotter died mysteriously. #{e}"

