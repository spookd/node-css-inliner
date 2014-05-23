packageData = require("../package.json")

# Parsing input
parseListArgumentAdvanced = (values, allowsRegularExpressions = no) ->
  throw new Error("Mismatched double quotes: #{values}") if values.match(/\"/g) and values.match(/\"/g).length % 2 is 1
  throw new Error("Mismatched single quotes: #{values}") if values.match(/\'/g) and values.match(/\'/g).length % 2 is 1

  values = values.split(/((?:\"[\s\S]*?\")|(?:'[\s\S]*?'))|(?:\,)/)
  result = []

  for value in values
    continue if not value or (value = value.replace(/(?:^(\s*)\"([\s\S]*)\"(\s*)$)|(?:^(\s*)'([\s\S]*)'(\s*)$)/, "$1$2$3$4$5$6").trim()) is ""

    expressionParts = value.match(/^\/(.*?)\/([gim]*)$/)
    if expressionParts
      value = new RegExp(expressionParts[1], expressionParts[2])
    
    result.push(value)

  return result

parseListArgument = (values) ->
  return parseListArgumentAdvanced(values)

parseListArgumentAllowingRegExp = (values) ->
  return parseListArgumentAdvanced(values, yes)

# Defining the CLI
program = require("commander").version(packageData.version)
.usage("[options] \n\t e.g. inlinecss --css-only --url http://getbootstrap.com/examples/jumbotron/ > styles.css")

.option("-u, --url <fake-url>",
    "a URL to fake when having stdin")

.option("-h, --html <html>",
    "JSON.stringify()'ed HTML string to parse")

.option("-c, --css-only",
    "only return the final CSS")

.option("-m, --css-media <media1,media2,mediaN>",
    "process stylesheets with media queries other than all, screen and empty", parseListArgumentAllowingRegExp)

.option("-M, --css-minify",
    "minify CSS using clean-css")

.option("-d, --css-id <id>",
    "ID-attribute to be set on the style-tag")

.option("-e, --expose-var <name>",
    "expose the stripped stylesheets in the specified JavaScript variable")

.option("-E, --expose-js <name>",
    "javascript to insert right below the exposed variable (set by -e)")

.option("-i, --ignore-sheets <sheet1,sheet2,sheetN>",
    "sheets to ignore (either exact URLs or regular expressions)", parseListArgumentAllowingRegExp)

.option("-I, --ignore-selectors <selector1,selector2,selectorN>",
    "selectors to ignore (either exact URLs or regular expressions)", parseListArgumentAllowingRegExp)

.option("-x, --ignore-external-sheets",
    "don't process external stylesheets")

.option("-D, --use-domino",
    "use Domino instead of PhantomJS")

.option("-l, --log",
    "print out log messages")

.parse(process.argv)

options =

  # Core
  log:                  program.log || no

  # CSS
  cssMedia:             program.cssMedia || ""
  cssMinify:            program.cssMinify || no
  cssOnly:              program.cssOnly || no
  cssId:                program.cssId || no
  # CSS: Expose
  exposeVar:            program.exposeVar || no
  exposeJS:             program.exposeJs || no

  # Ignore
  ignoreSheets:         program.ignoreSheets || []
  ignoreSelectors:      program.ignoreSelectors || []
  ignoreExternalSheets: program.ignoreExternalSheets || no

  useDomino:            program.useDomino || no

run = ->
  require("../index.js") options, (error, cssOrHtml) ->
    process.stderr.write("#{error}\n") if error
    process.stdout.write("#{cssOrHtml}\n") unless error
    process.exit(if error then 1 else 0)

if program.args.length is 0
  return program.help() unless program.url? and typeof program.url is "string"

  options.url  = program.url

  if program.html
    try
      options.html = JSON.parse("""{"html": "#{program.html.replace(/"/g, '\\"')}"}""").html
      console.log options.html
      process.exit()
      run()
    catch e
      process.stderr.write("Error: #{e.toString()}\n")
  else
    process.stdin.resume()
    process.stdin.setEncoding("utf8")

    options.html = ""

    failFn = ->
      program.help()

    dummy = setTimeout(failFn, 1000)
    
    process.stdin.on "data", (chunk) ->
      clearTimeout(dummy)
      options.html += chunk
    
    process.stdin.on "end", ->
      run()
else
  options.url = program.args.pop()
  run()