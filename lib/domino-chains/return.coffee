url = require("url")

module.exports = exports =
  exposeStylesheets: (document, options, sheets, finalCSS, next) ->
    return next(null) if not options.exposeVar or typeof options.exposeVar isnt "string"

    name = options.exposeVar
    script = document.createElement("script")
    script.innerHTML = "#{name} = #{JSON.stringify(sheets)};"
    script.innerHTML = "var " + script.innerHTML if name.indexOf(".") < 0
    script.innerHTML += "\n#{options.exposeJS}" if options.exposeJS
    document.getElementsByTagName("body")[0].appendChild(script)

    next(null)

  removeStylesheetsAndInjectUsedStyles: (document, options, sheets, finalCSS, next) ->
    links = document.querySelectorAll("link[rel='stylesheet']")
    linkForHref = (href) ->
      for link in links
        return link if href is url.resolve(options.url, link.href)

    for sheet in sheets
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
    
    next(null, document.documentElement.outerHTML)