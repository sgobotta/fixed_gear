// Makes "fg-#{ICON}" classes for every SVG in this folder, the same way
// vendor/heroicons.js does for "hero-*". Render them with <.icon name="fg-...">.
const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = plugin(function({matchComponents, theme}) {
  let values = {}
  fs.readdirSync(__dirname).filter(file => file.endsWith(".svg")).forEach(file => {
    let name = path.basename(file, ".svg")
    values[name] = {name, fullPath: path.join(__dirname, file)}
  })
  matchComponents({
    "fg": ({name, fullPath}) => {
      let content = encodeURIComponent(fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, ""))
      return {
        [`--fg-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
        "-webkit-mask": `var(--fg-${name})`,
        "mask": `var(--fg-${name})`,
        "mask-repeat": "no-repeat",
        "background-color": "currentColor",
        "vertical-align": "middle",
        "display": "inline-block",
        "width": theme("spacing.6"),
        "height": theme("spacing.6")
      }
    }
  }, {values})
})
