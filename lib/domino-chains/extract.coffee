async    = require("async")
request  = require("request")
css      = require("css")
CleanCSS = require("clean-css")
_        = require("lodash")
url      = require("url")

getElementAttributes = (el, ignore...) ->
  attrs = {}

  for attr of el.attributes when typeof el.attributes[attr] is "object" and typeof el.attributes[attr].data is "string"
    continue if ignore.indexOf(attr) isnt -1
    attrs[attr] = el.attributes[attr].data

  return attrs

module.exports = exports =
  extractStylesheets: (window, document, options, next) ->
    options.cout "Extracting stylesheets"
    links  = document.querySelectorAll("link[rel='stylesheet']")
    sheets = []

    for link in links
      attrs = getElementAttributes(link, "media", "rel")
      continue unless typeof attrs.href is "string"

      # Domino bug/incorrect usage?
      realHref = attrs.href

      delete attrs.href

      sheets.push
        href:        url.resolve(options.url, realHref)
        media:       link.media
        attributes:  attrs

    urlParsed = url.parse(options.url)

    sheets = sheets.filter (sheet) ->
      _.every options.ignoreSheets, (ignore) ->
        if ignore instanceof RegExp and ignore.test(sheet.href)
          options.cout "|> Ignoring stylesheet (#{sheet.href}) because of ignore-rule #{ignore.toString()}"
          return no

        return sheet.href isnt ignore

      if options.ignoreExternalSheets
        if urlParsed.hostname isnt url.parse(sheet.href).hostname
          options.cout "|> Ignoring stylesheet (#{sheet.href}) because external stylesheets are ignored"
          return no
        
        return true

    sheets = sheets.filter((sheet) -> return media.indexOf(sheet.media) isnt -1)

    next(null, sheets)

  downloadStylesheets: (window, document, options, sheets, next) ->
    if not sheets or sheets.length is 0
      options.cout "Refusing to continue: 0 stylesheets"
      return next("Refusing to continue: 0 stylesheets")

    options.cout "Downloading #{sheets.length} stylesheet(s)"

    mapFn = (sheet, done) ->
      requestOptions =
        headers:
          "User-Agent": options.userAgent

      request sheet.href, requestOptions, (error, response, body) ->
        if error
          options.cout "Failed to download stylesheet #{sheet.href}: #{error.toString()}"
        else if response.statusCode < 200 or response.statusCode > 399
          options.cout "Failed to download stylesheet #{sheet.href}: Status code not in valid range #{response.statusCode.toString()}"
        else
          options.cout "|> Stylesheet downloaded: #{sheet.href}"

        body = "" if not error and (response.statusCode < 200 or response.statusCode > 399)

        # Rebase url()'s
        body = body.replace /url\((["']|)([^"'\(\)]+)\1\)/g, (m, quote, uri) ->
          return "url(#{quote}#{url.resolve(sheet.href, uri)}#{quote})"

        sheet.body = body

        done(error, sheet)

    async.map(sheets, mapFn, next)

  parseStylesheets: (window, document, options, sheets, next) ->
    if sheets
      cssString = ""

      for sheet in sheets
        cssString += sheet.body

      options.cout "Parsing #{sheets.length} stylesheet(s) - #{cssString.split("\n").length} lines"

      try
        styles = css.parse(cssString).stylesheet
      catch e
        if e.line
          line = cssString.split("\n")[e.line - 1]
          line = line.substring(e.column - 40, e.column) if line.length > 40 and e.column
          e.message = "node-css-inliner: #{e.message}\n\t -> #{line.substring(0, 40)}"

        return next(e)
      
      next(null, sheets, styles)
    else
      next("Failed to download stylesheets")

  filter: (window, document, options, sheets, styles, next) ->
    options.cout "Starting to filter out rules ..."

    filterChain = require("./filter")
    
    for action of filterChain
      filterChain[action] = filterChain[action].bind(null, document, options, styles)

    async.waterfall _.toArray(filterChain), (error, usedStyles) ->
      next(error, sheets, styles, usedStyles)

  generateStyles: (window, document, options, sheets, styles, usedStyles, next) ->
    try
      finalCSS = css.stringify(stylesheet: rules: usedStyles)

      if options.cssMinify isnt no
        finalCSS = new CleanCSS(if typeof options.cssMinify is "object" then options.cssMinify else {}).minify(finalCSS)

      sheets = sheets.filter (sheet) ->
        delete sheet["body"]
        return yes

      next(null, sheets, finalCSS)
    catch e
      next(error)
    

