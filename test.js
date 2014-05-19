var inline = require("./index");

inline({url: "http://www.dr.dk/tv", html: require("fs").readFileSync(__dirname + "/tv.html"), useDomino: true, cssExpose: "DR", log: true}, function(error, cssOrHtml){
  console.log(cssOrHtml);
});