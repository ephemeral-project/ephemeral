var del = require('del'),
    exec = require('child_process').exec,
    fs = require('fs'),
    glob = require('glob'),
    gs = require('glob-stream'),
    gulp = require('gulp'),
    path = require('path'),
    mkdirp = require('mkdirp'),
    sequence = require('gulp-sequence')

const ADDONS = 'wow/Interface/AddOns/'

function addon(name) {
  return ADDONS + name;
}

function getFolders(dir) {
  return fs.readdirSync(dir).filter(function(files) {
    return fs.statSync(path.join(dir, file)).isDirectory()
  })
}

function constructWxTask(taskname, filename) {
  gulp.task(taskname, function(cb) {
    mkdirp(addon('ephemeral'))
    exec('python util/wx.py ' + filename + ' ' + addon('ephemeral'),
      function(err, stdout, stderr) {
        console.log(stdout)
        console.log(stderr)
        cb(err)
      }
    )
  })
}

var wxfiles = glob.sync('wx/*.wx')
for(var i = 0, l = wxfiles.length; i < l; i++) {
  constructWxTask(path.basename(wxfiles[i]), wxfiles[i])
}

gulp.task('resources', function() {
  mkdirp(addon('ephemeral'))
  return gulp.src('addon/**/*', {base: 'addon'})
    .pipe(gulp.dest(addon('ephemeral')))
})

gulp.task('lua', function() {
  mkdirp(addon('ephemeral'))
  return gulp.src('addon/*.lua')
    .pipe(gulp.dest(addon('ephemeral')))
})

gulp.task('wx', function(cb) {
  mkdirp(addon('ephemeral'))
  exec('python util/wx.py wx ' + addon('ephemeral'), function(err, stdout, stderr) {
    console.log(stdout)
    console.log(stderr)
    cb(err)
  })
})

gulp.task('regions', function(cb) {
  mkdirp(addon('ephemeral'))
  exec('python util/regions.py data/regions.csv ' + addon('ephemeral/regions.lua'), function(err, stdout, stderr) {
    console.log(stdout)
    console.log(stderr)
    cb(err)
  })
})

gulp.task('build',
  sequence('resources', 'lua', 'wx', 'regions')
)

gulp.task('watch', function() {
  for(var i = 0, l = wxfiles.length; i < l; i++) {
    var taskname = path.basename(wxfiles[i])
    gulp.watch(wxfiles[i], [taskname])
  }
  gulp.watch('addon/*.lua', ['lua'])
})
