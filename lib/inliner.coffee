async    = require("async")
_        = require("underscore")
Phantom  = require("./phantom")
domino   = require("domino")
request  = require("request")

defaultOptions =
  # Core
  log:             no

  # CSS
  cssMedia:        ""
  cssMinify:       no
  cssOnly:         no
  cssId:           no
  cssExpose:       no

  # Experimental
  useDomino:       no

  # Miscellaneous
  ignoreSheets:    []
  ignoreSelectors: []
  # ...
  userAgent:       "CSS Inliner for node.js by Nicolai Persson"

module.exports = exports = (options = {}, cb) ->
  options = _.extend(defaultOptions, options)

  if not options?.url?
    cb("The URL option is required both for 'faking' (i.e. for providing the HTML) and loading an actual website")
    return

  if options.log
    console.log "Inlining #{options.url}", if options.html then "(fake URL with content)" else "" 

  options.cout = (args...) ->
    console.log "──", args.join(" ") if options.log

  if not options.useDomino
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

        extractChain = require("./phantom-chains/extract")
        for action of extractChain
          extractChain[action] = extractChain[action].bind(null, page, options)

        async.waterfall _.toArray(extractChain), (error, stylesheets, finalCSS) ->
          return cb(error) if error

          if options.cssOnly
            cb(null, usedCss)
          else
            returnChain = require("./phantom-chains/return")

            for action of returnChain
              returnChain[action] = returnChain[action].bind(null, page, options, stylesheets, finalCSS)
            
            async.waterfall _.toArray(returnChain), cb
  else
    proceed = (html) ->
      window   = domino.createWindow(html)
      document = window.document

      window.location.href = options.url
      
      extractChain = require("./domino-chains/extract")
      for action of extractChain
        extractChain[action] = extractChain[action].bind(null, window, document, options)

      async.waterfall _.toArray(extractChain), (error, stylesheets, finalCSS) ->
        return cb(error) if error

        if options.cssOnly
          cb(null, usedCss)
        else
          returnChain = require("./domino-chains/return")

          for action of returnChain
            returnChain[action] = returnChain[action].bind(null, document, options, stylesheets, finalCSS)
          
          async.waterfall _.toArray(returnChain), cb

    if not options.html
      request options.url, "User-Agent": options.userAgent, (error, response, body) ->
        return cb(error) if error
        proceed(body)
    else
      proceed(options.html)