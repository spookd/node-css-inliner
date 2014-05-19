async   = require("async")
css     = require("css")
_       = require("lodash")

dePseudify = (->
  ignoredPseudos = [
    #/* link */
    ':link', ':visited',
    #/* user action */
    ':hover', ':active', ':focus',
    #/* UI element states */
    ':enabled', ':disabled', ':checked', ':indeterminate',
    #/* pseudo elements */
    '::first-line', '::first-letter', '::selection', '::before', '::after',
    #/* CSS2 pseudo elements */
    ':before', ':after'
  ]

  regex = new RegExp(ignoredPseudos.join('|'), 'g');

  return (selector) ->
    return selector.replace(regex, "")
)()

module.exports = exports =
  findSelectorsUsed: (page, options, styles, next, test) ->
    options.cout "|> Finding selectors used", test

    filterUsed = (rules, cb, recursive = no) ->
      concatFn = (rule, done) ->
        if rule.type is "rule"
          return done(null, rule.selectors)
        else if rule.type is "media"
          return filterUsed(rule.rules, done, yes)

        return done(null, [])

      filterFn = (error, selectors) ->
        return cb(error, selectors) if recursive

        evalFn = (selectors) ->
          selectors = selectors.filter (selector) ->
            try
              return yes if document.querySelector(selector)?
            catch e
              return yes

          return selectors

        resultsFn = (error, used_selectors) ->
          return cb(error, used_selectors)
        
        page.evaluate(evalFn, resultsFn, selectors.map(dePseudify))

      return async.concat(rules, concatFn, filterFn)

    filterUsed styles.rules, (error, usedSelectors) ->
      next(null, usedSelectors)

  removeUnusedRules: (page, options, styles, usedSelectors, next) ->
    options.cout "|> Removing unused selectors"
    selectorsToIgnore = options.ignoreSelectors

    filterEmptyRules = (rules) ->
      return rules.filter (rule) ->
        return rule.selectors.length isnt 0 if rule.type is "rule"

        if rule.type is "media"
          rule.rules = filterEmptyRules(rule.rules)
          return rule.rules.length isnt 0

        return yes

    filterSelectors = (selectors) ->
      return selectors.filter (selector) ->
        return yes if selector[0] is "@"

        for ignoreRule in selectorsToIgnore
          return ignoreRule.test(selector) if ignoreRule instanceof RegExp
          return yes if ignoreRule is selector

        return usedSelectors.indexOf(selector) isnt -1

    filterRules = (rules) ->
      for rule in rules
        if rule.type is "rule"
          rule.selectors = filterSelectors(rule.selectors)
        else if rule.type is "media"
          rule.rules = filterRules(rule.rules)

      return filterEmptyRules(rules)

    next(null, filterRules(styles.rules))