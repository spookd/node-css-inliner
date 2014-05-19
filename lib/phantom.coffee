phantom     = require("node-phantom-simple")
phantomPath = require('phantomjs').path

pool = require("generic-pool").Pool
  name: "phantomjs"
  max:  require("os").cpus().length
  idleTimeoutMillis: 30000
  log: no

  create: (cb) ->
    options =
      phantomPath: phantomPath
      parameters:
        "ignore-ssl-errors": "yes"
        "load-images":       "no"

    callback = (error, ph) ->
      cb(error, ph)

    phantom.create(callback, options)

  destroy: (ph) ->
    ph.exit()

module.exports = exports = pool