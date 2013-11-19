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
        src: "sass/**.scss"

      js:
        vendor: [
          "lib/jquery/jquery.js"
          "lib/jquery.cookie/jquery.cookie.js"
          "lib/keymaster/keymaster.js"
          "lib/moment/moment.js"
          "lib/underscore/underscore.js"
          "lib/backbone/backbone.js"
        ]

        app:
          client:
            main: "src/client/main.js.coffee"
            compiled: "<%= public_dir %>js/app.min.js"
          server:
            src: "src/server/**.coffee"

      templates:
        src: "app/templates/**/*.hb"
        compiled: "generated/template-cache.js"

    # task configuration
    sass:
      dist:
        files:
          '<%= public_dir %>css/main.css' : 'sass/combined.scss'
    cssmin:
      dist:
        src: '<%= public_dir %>css/main.css'
        dest: '<%= public_dir %>css/main.css'



    browserify:
      app:
        files:
          "<%= files.js.app.client.compiled %>" : "<%= files.js.app.client.main %>"
        options:
          debug: true
          transform: ["coffeeify"]

    concat_sourcemap:
      options:
        sourcesContent: true
      app:
        src: [
          "<%= files.js.vendor %>"
          "<%= files.templates.compiled %>"
        ]
        dest: "<%= public_dir %>js/vendor.min.js"

    watch:
      options:
        livereload: true

      # targets for watch
      html:
        files: ["<%= files.html.src %>"]
        tasks: ["copy"]

      js:
        files: ["<%= files.js.vendor %>"]
        tasks: ["concat_sourcemap"]

      coffee:
        files: ["src/**/*.coffee"]
        tasks: ["browserify", "concat_sourcemap"]

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

    server:
      base: "#{process.env.SERVER_BASE || 'generated'}"
      web:
        port: 8000

    exec:
      server:
        command: 'supervisor -n error -w . src/server/main.coffee'
        stdout: true

    # open:
    #   dev:
    #     path: "http://localhost:<%= server.web.port %>"

    uglify:
      options:
        banner: "<%= banner %>"

      dist:
        sourceMapIn: "<%= public_dir %>js/app.min.js.map"
        sourceMap:   "<%= public_dir %>js/app.min.js.map"
        src: "<%= concat_sourcemap.app.dest %>" # input from the concat_sourcemap process
        dest: "<%= public_dir %>js/app.min.js"

    clean:
      workspaces: ["dist", "generated"]

  # loading local tasks
  grunt.loadTasks "tasks"

  # loading external tasks (aka: plugins)
  # Loads all plugins that match "grunt-", in this case all of our current plugins
  require('matchdep').filterAll('grunt-*').forEach(grunt.loadNpmTasks)

  # creating workflows
  # grunt.registerTask "default", ["sass:dist", "cssmin", "browserify", "concat_sourcemap", "copy", "server", "open", "watch"]
  grunt.registerTask "build", ["clean", "sass:dist", "cssmin", "browserify", "concat_sourcemap", "uglify", "copy"]
  # grunt.registerTask "prodsim", ["build", "server", "open", "watch"]
