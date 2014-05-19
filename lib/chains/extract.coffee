async    = require("async")
request  = require("request")
css      = require("css")
CleanCSS = require("clean-css")
_        = require("underscore")

filterChain  = require("./filter")

module.exports = exports =
  loadPageContent: (page, options, next) ->
    if typeof options.html is "string"
      didCallNext = no
      options.cout("Loading page content from HTML option")

      page.onLoadFinished = (args...) ->
        return if didCallNext
        didCallNext = yes
        next(null)

      page.setContent options.html, options.url
    else
      options.cout("Loading page content")
      page.open options.url, (error, status) ->
        next(error)


  extractStylesheets: (page, options, next) ->
    options.cout "Extracting stylesheets from page"
    media = _.union(["", "all", "screen"], options.cssMedia)

    evalFn = ->
      return Array.prototype.map.call document.querySelectorAll("link[rel='stylesheet']"), (link) ->

        data =
          href:  link.href
          media: link.media
          attributes: {}

        for attr in link.attributes
          continue if attr.name is "href" or attr.name is "media"
          data.attributes[attr.name] = attr.value

        return data

    resultsFn = (error, stylesheets) ->
      stylesheets ||= []

      # Loop through ignore list
      stylesheets = stylesheets.filter (sheet) ->
        _.every options.ignoreSheets, (ignore) ->
          if ignore instanceof RegExp and ignore.test(sheet.href)
            options.cout "|> Ignoring stylesheet (#{sheet.href}) because of ignore-rule #{ignore.toString()}"
            return no

          return sheet isnt ignore

      stylesheets = stylesheets.filter((sheet) -> return media.indexOf(sheet.media) isnt -1)

      next(error, stylesheets)

    page.evaluate(evalFn, resultsFn)


  downloadStylesheets: (page, options, stylesheets, next) ->
    if not stylesheets or stylesheets.length is 0
      options.cout "Refusing to continue: 0 stylesheets"
      return next("Refusing to continue: 0 stylesheets", stylesheets)

    options.cout "Downloading #{stylesheets.length} stylesheet(s)"

    mapFn = (sheet, done) ->
      requestOptions =
        headers:
          "User-Agent": "CSS Inliner for node.js"

      request sheet.href, requestOptions, (error, response, body) ->
        if error
          options.cout "Failed to download stylesheet #{sheet.href}: #{error.toString()}"
        else if response.statusCode < 200 or response.statusCode > 399
          options.cout "Failed to download stylesheet #{sheet.href}: Status code not in valid range #{response.statusCode.toString()}"
        else
          options.cout "|> Stylesheet downloaded: #{sheet.href}"

        body = "" if not error and (response.statusCode < 200 or response.statusCode > 399)

        sheet.body = body

        done(error, sheet)

    async.map(stylesheets, mapFn, next)


  parseStylesheets: (page, options, stylesheets, next) ->
    if stylesheets
      cssString = ""

      for sheet in stylesheets
        cssString += sheet.body

      options.cout "Parsing #{stylesheets.length} stylesheet(s) - #{cssString.split("\n").length} lines"

      try
        styles = css.parse(cssString).stylesheet
      catch e
        if e.line
          line = cssString.split("\n")[e.line - 1]
          line = line.substring(e.column - 40, e.column) if line.length > 40 and e.column
          e.message = "node-css-inliner: #{e.message}\n\t -> #{line.substring(0, 40)}"

        return next(e)
      
      next(null, stylesheets, styles)
    else
      next("Failed to download stylesheets")


  filter: (page, options, stylesheets, styles, next) ->
    options.cout "Starting to filter out rules ..."

    for action of filterChain
      filterChain[action] = filterChain[action].bind(null, page, options, styles)

    async.waterfall _.toArray(filterChain), (error, usedStyles) ->
      next(error, stylesheets, styles, usedStyles)

  generateStyles: (page, options, stylesheets, styles, usedStyles, next) ->
    try
      finalCSS = css.stringify(stylesheet: rules: usedStyles)

      if options.cssMinify isnt no
        finalCSS = new CleanCSS(if typeof options.cssMinify is "object" then options.cssMinify else {}).minify(finalCSS)

      stylesheets = stylesheets.filter (sheet) ->
        delete sheet["body"]
        return yes

      next(null, stylesheets, finalCSS)
    catch e
      next(error)
    