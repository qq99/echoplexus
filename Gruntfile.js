/*global module:false*/
module.exports = function(grunt) {
  var _      = grunt.util._,
    config = require('./client/config');//Load r.js config
  config.shim = _.extend(config.shim,{main: []});
  _.each(config.config.loader.modules,function(val){config.shim.main.push('modules/'+val.name+'/client');});
  console.log(config);
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
    requirejs:{
      dist: {
        options: _.merge(config, { // Here, we merge to override config, if needed
          findNestedDependencies: true,
          baseUrl       : '<%= client_dir %>',
          name          : 'config',
          out           : '<%= client_dir %>main.build.js'
          //optimize: 'none'
        })
      }
    },
    strip: {
      dist: {
        src: '<%= requirejs.dist.options.out %>',
        dest: '<%= requirejs.dist.options.out %>'
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
          "<%= client_dir %>main.build.js",
          "<%= public_dir %>css/main.css",
          "<%= public_dir %>css/main.min.css",
          "<%= public_dir %>css/"
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
  grunt.loadNpmTasks('grunt-strip');

  // Default task.
  grunt.registerTask('default', ['clean','requirejs','strip','sass','cssmin']);

  //TODO: developer task
};
