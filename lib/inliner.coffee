async        = require("async")
_            = require("lodash")
Phantom      = require("./phantom")

extractChain = require("./chains/extract")
returnChain  = require("./chains/return")

defaultOptions =
  # Core
  log:                  no

  # CSS
  cssMedia:             ""
  cssMinify:            no
  cssOnly:              no
  cssId:                no
  cssExpose:            no

  # Miscellaneous
  ignoreSheets:         []
  ignoreSelectors:      []
  ignoreExternalSheets: no

module.exports = exports = (options = {}, cb) ->
  options = _.extend(defaultOptions, options)

  # Validate options
  if not options?.url?
    cb("The URL option is required both for 'faking' (i.e. for providing the HTML) and loading an actual website")
    return false

  for attribute of options
    switch attribute
      when "log", "cssOnly", "ignoreExternalSheets"
        if not _.isBoolean(options[attribute])
          cb('Options type error: "log", "cssOnly", "ignoreExternalSheets" must be booleans.')   
          return false
      when "ignoreSheets", "ignoreSelectors"
        if not _.isArray(options[attribute])
          cb('Options type error: "ignoreSheets", "ignoreSelectors" must be arrays.')
          return false

  # Aquire a PhantomJS instance from our pool
  Phantom.acquire (error, ph) ->
    if error
      Phantom.release(ph)
      cb(error)
      return

    # Create a page
    ph.createPage (error, page) ->
      origCb = cb
      cb     = (e, cssOrHtml) ->
        page.close()
        Phantom.release(ph)
        origCb(e, cssOrHtml)

      return cb(error) if error

      if options.log
        console.log "Inlining #{options.url}", if options.html then "(fake URL with content)" else "" 

      options.cout = (args...) ->
        console.log "──", args.join(" ") if options.log

      for action of extractChain
        extractChain[action] = extractChain[action].bind(null, page, options)

      async.waterfall _.toArray(extractChain), (error, stylesheets, finalCSS) ->
        return cb(error) if error

        if options.cssOnly
          cb(null, usedCss)
        else
          for action of returnChain
            returnChain[action] = returnChain[action].bind(null, page, options, stylesheets, finalCSS)
          
          async.waterfall _.toArray(returnChain), cb
