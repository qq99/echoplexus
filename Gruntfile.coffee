module.exports = (grunt) ->

  # task configurations
  # initializing task configuration
  grunt.initConfig

    # meta data
    pkg: grunt.file.readJSON("package.json")
    banner: "/*! <%= pkg.title || pkg.name %> - v<%= pkg.version %> - " +
      "<%= grunt.template.today(\"yyyy-mm-dd\") %>\n" +
      "<%= pkg.homepage ? \"* \" + pkg.homepage + \"\\n\" : \"\" %>" +
      "* Copyright (c) <%= grunt.template.today(\"yyyy\") %> <%= pkg.author.name %>;" +
      " Licensed <%= _.pluck(pkg.licenses, \"type\").join(\", \") %> */\n"

    # files that our tasks will use
    public_dir: 'public/',
    client_dir: 'client/',
    files:
      html:
        src: "app/index.html"

      sass:
        src: [
          "sass/**.scss"
          "sass/ui/**.scss"
        ]

      js:
        vendor: [
          "vendor/jquery/jquery.js"
          "vendor/jquery.cookie/jquery.cookie.js"
          "vendor/keymaster/keymaster.js"
          "vendor/moment/moment.js"
          "vendor/underscore/underscore.js"
          "vendor/backbone/backbone.js"
          "vendor/backbone.stickit/backbone.stickit.js"
          "vendor/codemirror/lib/codemirror.js"
          "vendor/codemirror/mode/xml/xml.js"
          "vendor/codemirror/mode/css/css.js"
          "vendor/codemirror/mode/javascript/javascript.js"
          "vendor/codemirror/mode/htmlmixed/htmlmixed.js"
          "vendor/codemirror/mode/htmlembedded/htmlembedded.js"
          "vendor/hammerjs/hammer.js"
          "vendor/emojify.js/emojify.js"
          "vendor/spectrum/spectrum.js"
          "lib/CryptoJS-3.1.2/components/core.js"
          "lib/CryptoJS-3.1.2/components/enc-base64.js"
          "lib/CryptoJS-3.1.2/components/enc-utf16.js"
          "lib/CryptoJS-3.1.2/rollups/aes.js"
        ]

        app:
          main: "src/client/bootstrap.desktop.js.coffee"
          compiled: "<%= public_dir %>js/app.min.js"

        mobile:
          main: "src/mobile/bootstrap.mobile.js.coffee"
          compiled: "<%= public_dir %>js/mobile.min.js"

        embedded:
          main: "src/embedded-client/main.js.coffee"
          compiled: "<%= public_dir %>js/embedded.app.min.js"

      templates:
        src: "app/templates/**/*.hb"
        compiled: "generated/template-cache.js"

    # task configuration
    sass:
      dist:
        files:
          '<%= public_dir %>css/main.css' : 'sass/combined.scss'
          '<%= public_dir %>css/embedded.css' : 'sass/embedded.scss'

    cssmin:
      dist:
        src: '<%= public_dir %>css/main.css'
        dest: '<%= public_dir %>css/main.css'
      embedded:
        src: '<%= public_dir %>css/embedded.css'
        dest: '<%= public_dir %>css/embedded.css'

    browserify:
      app:
        files:
          "<%= files.js.app.compiled %>" : "<%= files.js.app.main %>"
        options:
          debug: true
          transform: ["coffeeify", "node-underscorify"]

      embedded:
        files:
          "<%= files.js.embedded.compiled %>" : "<%= files.js.embedded.main %>"
        options:
          debug: true
          transform: ["coffeeify", "node-underscorify"]

      mobile:
        files:
          "<%= files.js.mobile.compiled %>" : "<%= files.js.mobile.main %>"
        options:
          debug: true
          transform: ["coffeeify", "node-underscorify"]

    concat_sourcemap:
      options:
        sourcesContent: true
      app:
        src: [
          "<%= files.js.vendor %>"
          #"<%= files.templates.compiled %>"
        ]
        dest: "<%= public_dir %>js/vendor.min.js"

    watch:
      options:
        livereload: true

      # targets for watch
      js:
        files: ["<%= files.js.vendor %>"]
        tasks: ["concat_sourcemap"]

      coffee:
        files: ["src/client/**/*.coffee", "src/client/**/*.html", "src/embedded-client/**/*.coffee", "src/embedded-client/**/*.html"]
        tasks: ["browserify:app", "browserify:embedded", "browserify:mobile", "concat_sourcemap"]

      sass:
        files: ["<%= files.sass.src %>"]
        tasks: ["sass","cssmin"]

    # imagemin:
    #   dist:
    #     files: [
    #       expand: true,
    #       cwd: 'app/img'
    #       src: '**/*.{png,jpg,jpeg}'
    #       dest: 'generated/img-min'
    #     ]

    # handlebars:
    #   options:
    #     namespace: "JST"
    #     wrapped: true
    #   compile:
    #     src: "<%= files.templates.src %>"
    #     dest: "<%= files.templates.compiled %>"

    copy:
      html:
        files:
          "generated/index.html" : "<%= files.html.src %>"
          "dist/index.html"      : "<%= files.html.src %>"
      emojify:
        files: [
          expand: true
          src: "vendor/emojify.js/images/**"
          flatten: true
          dest: "public/images/emoji"
        ]
      fontawesome:
        files: [
          expand: true
          src: "vendor/fontawesome/fonts/**"
          flatten: true
          dest: "public/fonts"
        ]
      openpgp:
        files:
          "<%= public_dir %>js/openpgp.min.js": "lib/openpgpjs/openpgp.min.js"
          "<%= public_dir %>js/openpgp.worker.min.js": "lib/openpgpjs/openpgp.worker.min.js"

    server:
      base: "#{process.env.SERVER_BASE || 'generated'}"
      web:
        port: 8000

    exec:
      server:
        command: 'supervisor -n error -w src/server src/server/main.coffee'
        stdout: true
      production:
        command: 'supervisor --poll-interval 60000 -w . src/server/main.coffee'
        stdout: true
      dependencies:
        command: 'npm install; bower install;'
        stdout: true
      download_apk:
        command: 'wget https://controller.apk.firefox.com/application.apk?manifestUrl=https%3A%2F%2Fchat.echoplex.us%2Fmanifest.webapp -O echoplexus.apk'
      zipalign:
        command: 'zipalign -f 4 echoplexus.apk echoplexus.zipaligned.apk; zipalign -c -v 4 echoplexus.zipaligned.apk'

    uglify:
      options:
        banner: "<%= banner %>"

      desktop:
        sourceMapIn: "<%= files.js.app.compiled %>.map"
        sourceMap:   "<%= files.js.app.compiled %>.map"
        src: "<%= files.js.app.compiled %>" # input from the concat_sourcemap process
        dest: "<%= files.js.app.compiled %>"

      mobile:
        sourceMapIn: "<%= files.js.mobile.compiled %>.map"
        sourceMap: "<%= files.js.mobile.compiled %>.map"
        src: "<%= files.js.mobile.compiled %>"
        dest: "<%= files.js.mobile.compiled %>"

      embedded:
        sourceMapIn: "<%= files.js.embedded.compiled %>.map"
        sourceMap: "<%= files.js.embedded.compiled %>.map"
        src: "<%= files.js.embedded.compiled %>"
        dest: "<%= files.js.embedded.compiled %>"

      vendor:
        sourceMapIn: "<%= public_dir %>js/vendor.min.js.map"
        sourceMap:   "<%= public_dir %>js/vendor.min.js.map"
        src: "<%= public_dir %>js/vendor.min.js"
        dest: "<%= public_dir %>js/vendor.min.js"

    clean:
      workspaces: ["build"]

  # loading local tasks
  #grunt.loadTasks "tasks"

  # loading external tasks (aka: plugins)
  # Loads all plugins that match "grunt-", in this case all of our current plugins
  require('matchdep').filterAll('grunt-*').forEach(grunt.loadNpmTasks)

  # creating workflows
  grunt.registerTask "default", ["sass:dist", "cssmin", "browserify", "concat_sourcemap", "copy", "watch"]
  grunt.registerTask "build", ["clean", "exec:dependencies", "sass:dist", "cssmin", "browserify", "concat_sourcemap", "uglify", "copy"]
  grunt.registerTask "apk", ["exec:download_apk", "exec:zipalign"]
  # grunt.registerTask "prodsim", ["build", "server", "open", "watch"]
