/*global module:false*/
module.exports = function(grunt) {
  var _      = grunt.util._,
    config = require('./client/app');//Load r.js config
  config.shim = _.extend(config.shim,{main: []});
  _.each(config.config.loader.modules,function(val){config.shim.main.push('modules/'+val.name+'/client');});
  // Project configuration.
  grunt.initConfig({
    // Metadata.
    pkg: grunt.file.readJSON('package.json'),
    banner: '/*! <%= pkg.title || pkg.name %> - v<%= pkg.version %> - ' +
      '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
      '<%= pkg.homepage ? "* " + pkg.homepage + "\\n" : "" %>' +
      '* Copyright (c) <%= grunt.template.today("yyyy") %> <%= pkg.author%>;' +
      ' Licensed under <%= pkg.licenses.type %> */\n',
    public_dir: 'public/',
    client_dir: 'client/',
    // Task configuration.
    // HTML
    index:{
      build: '<%= public_dir %>index.build.html',
      dev: '<%= public_dir %>index.dev.html',
      nw: '<%= public_dir %>index.nw.html'
    },
    copy:{
      dist: {
        files: {
          '<%= index.build %>': '<%= index.dev %>'
        }
      }
    },
    'useminPrepare':{
      html: '<%= index.dev %>'
    },
    usemin: {
      html: ['<%= index.build %>']
    },
    htmlmin:{
      dist: {
        options: {
          removeComments: true,
          collapseWhitespace: true
        },
        files: {
          '<%= index.build %>': '<%= index.build %>'
        }
      }
    },
    // JS
    requirejs:{
      dist: {
        options: _.merge(config, { // Here, we merge to override config, if needed
          findNestedDependencies: true,
          baseUrl       : '<%= client_dir %>',
          name          : 'app',
          out           : '<%= client_dir %>app.min.js'
          //optimize: 'none'
        })
      }
    },
    mocha: {
      // Test all files ending in .html anywhere inside the test directory.
      browser: ['tests/testrunner.html'],
      options: {
        reporter: 'Nyan', // Duh!
        run: true
      }
    },
    strip: {
      dist: {
        src: '<%= requirejs.dist.options.out %>',
        dest: '<%= requirejs.dist.options.out %>'
      }
    },
    coffee: {
      src: {
        options: {
          bare: true
        },
        expand: true,
        cwd: 'src',
        src: ['**/*.coffee'],
        dest: 'build',
        ext: '.js'
      },
      test: {
        options: {
          bare: true
        },
        expand: true,
        cwd: 'tests',
        src: ['**/*.coffee'],
        dest: 'tests',
        ext: '.js'
      }
    },
    //CSS
    sass: {
      dist: {
        files: {
          '<%= public_dir %>css/main.css' : 'sass/combined.scss'
        }
      }
    },
    cssmin: {
      dist: {
        src: '<%= public_dir %>css/main.css',
        dest: '<%= public_dir %>css/main.css'
      }
    },
    //Clean
    clean: {
      options: {
      	force: true
      },
      build: {
        src: [
          "<%= client_dir %>app.min.js",
          "<%= public_dir %>css/main.css",
          "<%= public_dir %>css/",
          "<%= public_dir %>index.build.html",
          "build/*"
        ]
      },
      nw: {
        src: [
          "nw/app.nw"
        ]
      }
    },
    exec: {
      launch_app: {
        cmd: function() {
          if (require('os').platform() === "win32") {
            return 'nw.exe app.nw';
          }
          return './nw app.nw';
        },
        cwd: 'nw/'
      }
    },
    compress: {
      pack_app: {
      	options: {
      		archive: 'nw/app.nw',
      		mode: 'zip'
      	},
      	files: [
          {expand: true, src: ['node_modules/growl/**']},
      		{expand: true, src: ['**/*'], cwd: '<%= public_dir %>'},
      		{
            expand: true,
            src: _.union([
                '<%= client_dir %>**',
                '!<%= client_dir %>lib/**',
                '<%= client_dir %>lib/requirejs/require.js'
              ],_.map(config.paths,function(path){
                return '<%= client_dir %>' + path + '.js'
              })
            )
          },
      		{expand: true, src: ['package.json']}
      	]
      }
    }
  });

  // These plugins provide necessary tasks.
  //grunt.loadNpmTasks('grunt-strip');
  grunt.loadNpmTasks('grunt-sass');
  grunt.loadNpmTasks('grunt-css');
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-requirejs');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-strip');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-contrib-htmlmin');
  grunt.loadNpmTasks('grunt-usemin');
  grunt.loadNpmTasks('grunt-exec');
  grunt.loadNpmTasks('grunt-contrib-compress');
  grunt.loadNpmTasks('grunt-mocha');

  // Default task.
  grunt.registerTask('default', ['clean','copy','useminPrepare','requirejs','strip','usemin','htmlmin','sass','cssmin']);
  grunt.registerTask('dev', ['clean','coffee:src','sass']);
  grunt.registerTask('test', ['mocha']);
  grunt.registerTask('compile', ['coffee']);
  grunt.registerTask('nw', ['clean', 'sass', 'compress:pack_app']);
  grunt.registerTask('nw_launch', ['nw', 'exec:launch_app']);

  //TODO: developer task
};
