gutil = require('gulp-util')
through = require('through2')
sysPath = require('path')
fs = require('fs')
progeny = require('./parse')

depCache = {}
processedFileNames = {}

makeFile = (path, type, base, cwd) ->
	file = new gutil.File({
		base: base
		cwd: cwd
		path: path
	})
	if type is 'stream'
		file.contents = fs.createReadStream(path)
	else
		file.contents = fs.readFileSync(path)
	file


initParseConfig = (config) ->
	parser = progeny(config)
	(path) ->
		# clear old dependencies
		Object.keys(depCache).forEach (key) ->
			if path of depCache[key]
				delete depCache[key][path]
		parser(path)
			.filter(fs.existsSync)
			.forEach((dep) ->
				depCache[dep] ?= {}
				depCache[dep][path] = 1
			)

module.exports = (config) ->
	getDeps = initParseConfig(config)
	return through.obj (file, enc, cb) ->
		if file.isNull()
			@push(file)
			return cb()

		path = file.path
		type = file.isStream() ? 'stream' : 'buffer'
		cwd = file.cwd
		base = file.base
		@push(file)
		getDeps(path)

		# do nothing when start up
		if !processedFileNames[path]
			processedFileNames[path] = 1
			return cb()

		cache = (depCache[path] ?= {})
		deps = Object.keys(cache)
			.filter(fs.existsSync)
		# refresh cache
		cache = depCache[path] = {}
		for childPath in deps
			@push(makeFile(childPath, type, base, cwd))
			cache[childPath] = 1
		cb()
