/*global module:false*/
module.exports = function(grunt) {

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
    // Task configuration.
    // Concatenation
    concat: {
      options: {
        banner: '<%= banner %>',
        stripBanners: true
      },
      libs: {
        //The order of libs is important
        src: [
          'client/lib/underscore-min.js',
          'client/lib/jquery.min.js',
          'client/lib/jquery.cookie.js',
          'client/lib/moment.min.js',
          'client/lib/backbone/backbone.js',
          'client/lib/codemirror-3.11/lib/codemirror.js',
          'client/lib/codemirror-3.11/mode/javascript/javascript.js',
          'client/lib/codemirror-3.11/mode/xml/xml.js',
          'client/lib/codemirror-3.11/mode/css/css.js',
          'client/lib/codemirror-3.11/mode/htmlmixed/htmlmixed.js',
          'client/lib/keymaster.js'
        ],
        dest: '<%= public_dir %>libs.min.js'
      },
      //The rest of the scripts
      scripts: {
        src: ['client/**/*.js','!client/lib/**'],
        dest: '<%= public_dir %>echoplexus.min.js'
      }
    },
    strip: {
      libs: {
        src: '<%= concat.libs.dest %>',
        dest: '<%= concat.libs.dest %>'
      },
      scripts: {
        src: '<%= concat.scripts.dest %>',
        dest: '<%= concat.scripts.dest %>'
      }
    },
    uglify: {
      options: {
        banner: '<%= banner %>'
      },
      libs: {
        src: '<%= concat.libs.dest %>',
        dest: '<%= concat.libs.dest %>'
      },
      scripts: {
        src: '<%= concat.scripts.dest %>',
        dest: '<%= concat.scripts.dest %>'
      }
    },
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
    clean: {
      build: {
        src: [
          "<%= public_dir %>libs.min.js",
          "<%= public_dir %>echoplexus.min.js",
          "<%= public_dir %>css/main.css",
          "<%= public_dir %>css/main.min.css",
          "<%= public_dir %>css/"
        ]
      }
    }
  });

  // These plugins provide necessary tasks.
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-strip');
  grunt.loadNpmTasks('grunt-sass');
  grunt.loadNpmTasks('grunt-css');
  grunt.loadNpmTasks('grunt-contrib-clean');

  // Default task.
  grunt.registerTask('default', ['concat','strip','uglify','sass','cssmin']);

  //Developer task TODO: add more features like jshint
  grunt.registerTask('dev',['concat:scripts','sass','cssmin']);
};
