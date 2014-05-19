# CSS inliner
A [node.js](http://nodejs.org) module inlining used styles on a given page, as proposed by the Google Pagespeed team: [Optimizing the Critical Rendering Path for Instant Mobile Websites - Velocity SC - 2013](https://www.youtube.com/watch?v=YV1nKLWoARQ)

## How it works
The inliner works by loading the content in PhantomJS, extracting and parsing the CSS used, stripping away any CSS not being used. Stylesheets are downloaded seperately to avoid any browser-bias there might be.

It supports loading content through a URL or by passing on the HTML and a "fake" URL.

## Usage
```js
var inliner = require("css-inliner");

inliner({
  url: "http://www.dr.dk/tv"
}, function(error, html) {
  if (!error) {
    // Do whatever you want with the HTML
  }
});
```

#### Options
| Option              |  Default  | Description      |
| ------------------- | :-------: | ---------------- |
| **url**             | `nil`     | **Requred:** The URL to be loaded (or faked, if the HTML is specified). |
| **html**            | `nil`     | The HTML content to use, instead of loading the URL specified. |
| **cssMedia**        | `nil`     | By default it only processes stylesheets with media query `all`, `screen`, and those without one. Specify here which others to include. |
| **cssMinify**       | `false`   | Can be either a boolean (`true`) or an object with parameters to pass on to the [clean-css](https://github.com/GoalSmashers/clean-css) module. |
| **cssOnly**         | `false`   | If `true`, it'll return the CSS only. No HTML. |
| **cssId**           | `nil`     | The `id`-attribute to be set on the `<style>`-tag. |
| **cssExpose**       | `false`   | All the stripped stylesheets can be exposed in a JavaScript-variable, at the bottom of the `<body>`-tag, for you to use (i.e. loading the stylesheets when the page has finished loading). |
| **ignoreSheets**    | `nil`     | An array of stylesheets to ignore. Can be either exact strings or regular expressions (or a mix of those). |
| **ignoreSelectors** | `nil`     | An array of selectors/rules to keep at all times. These will not be stripped. Can be either exact strings or regular expressions (or a mix of those). |
| **log**             | `false`   | Whether or not to print out log messages. |

## Contributing or contact me
Any contributions are welcome. Simply fork the repository and make a pull request describing what you added/changed/fixed.

You can contact me through [Twitter](http://twitter.com/nicopersson) or by [creating an issue at my feedback repository](https://github.com/spookd/feedback/issues/new).

## License
This module is released under the [Apache 2.0 License](http://www.apache.org/licenses/LICENSE-2.0.html).