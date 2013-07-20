// usage: phantomjs this_file url file.out [width height]

var page = require('webpage').create(),
    system = require('system'),
    w = 1024, h = 768,
    address, output, size;

    address = system.args[1];
    output = system.args[2];
    page.viewportSize = { width: w, height: h };
    page.clipRect = { width: w, height: h };
    if (system.args.length === 5) // if a resolution was supplied
    {
        var w = system.args[3], h = system.args[4];
        page.viewportSize = {
            width: w,
            height: h
        }
        page.clipRect = {
            top: 0,
            left: 0,
            width: w,
            height: h
        };
    }

    page.open(address, function (status) {
        if (status !== 'success') {
            console.log('Unable to load the address!');
        } else {
            window.setTimeout(function () { // have to give phantom time to start up
                
                var extracted_information = {
                    title: page.title
                };

                // extract some data from the page:
        		var data = page.evaluate(function () {
        		    return {
                        excerpt: document.getElementsByTagName("p")[0].textContent
        		    };
        		});

        		if (typeof data.excerpt !== "undefined") {
                    data.excerpt = data.excerpt.trim().replace(/\n/g, "");
                    if (data.excerpt.length > 512) {
                        data.excerpt = data.excerpt.substring(0,512) + "...";
                    }
                    extracted_information.excerpt = data.excerpt;
        		}

                console.log(JSON.stringify(extracted_information));

                page.render(output);
                phantom.exit();
            }, 200);
        }
    });
