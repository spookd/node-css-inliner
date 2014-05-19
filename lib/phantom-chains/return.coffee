module.exports = exports =
  exposeStylesheets: (page, options, stylesheets, finalCSS, next) ->
    return next(null) if not options.cssExpose or typeof options.cssExpose isnt "string"

    evalFn = (name, stylesheets) ->
      script = document.createElement("script")
      script.innerHTML = "var #{name} = #{JSON.stringify(stylesheets)};"
      return document.getElementsByTagName("body")[0].appendChild(script)

    resultFn = (error) ->
      next(error)

    page.evaluate(evalFn, resultFn, options.cssExpose, stylesheets)

  removeStylesheetsAndInjectUsedStyles: (page, options, stylesheets, finalCSS, next) ->
    evalFn = (options, stylesheets, finalCSS) ->
      links = document.querySelectorAll("link[rel='stylesheet']")
      linkForHref = (href) ->
        for link in links
          return link if link.href is href

      try
        for sheet in stylesheets
          el = linkForHref(sheet.href)
          continue unless el

          if first?
            el.parentNode.removeChild(el)
          else
            first = el

        style = document.createElement("style")
        style.setAttribute("type", "text/css")
        style.setAttribute("id", options.cssId) if options.cssId? and typeof options.cssId is "string"
        style.innerHTML = finalCSS

        if first?
          first.parentNode.replaceChild(style, first)
        else
          document.getElementsByTagName("head")[0].appendChild(style)
        
        return document.documentElement.outerHTML
      catch e
        return no

    resultFn = (error, result) ->
      error = "Failed to finalize HTML" unless typeof result is "string"
      next(error, result)

    page.evaluate(evalFn, resultFn, options, stylesheets, finalCSS)