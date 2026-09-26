function normalize(monitors, screens) {
  var result = []
  for (var i = 0; i < monitors.length; i++) {
    var m = monitors[i]
    if (!m || m.disabled || m.mirrorOf && m.mirrorOf !== "none") continue
    var screen = null
    for (var j = 0; j < (screens || []).length; j++) {
      if (screens[j].name === m.name) {
        screen = screens[j]
        break
      }
    }
    var scale = Number(m.scale) || 1
    var width = Number(m.width) / scale
    var height = Number(m.height) / scale
    if (Math.abs(Number(m.transform) || 0) % 2 === 1) {
      var swap = width
      width = height
      height = swap
    }
    // ShellScreen dimensions already include output transform and scale.
    if (screen && screen.width > 0 && screen.height > 0) {
      width = screen.width
      height = screen.height
    }
    if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) continue
    result.push({
      name: String(m.name),
      model: String(m.model || m.description || ""),
      x: Number(m.x) || 0,
      y: Number(m.y) || 0,
      width: width,
      height: height
    })
  }
  return result.sort(function(a, b) { return a.y - b.y || a.x - b.x })
}

function bounds(monitors) {
  if (!monitors.length) return { x: 0, y: 0, width: 1, height: 1 }
  var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (var i = 0; i < monitors.length; i++) {
    var m = monitors[i]
    minX = Math.min(minX, m.x)
    minY = Math.min(minY, m.y)
    maxX = Math.max(maxX, m.x + m.width)
    maxY = Math.max(maxY, m.y + m.height)
  }
  return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
}

function rect(monitor, area, width, height, padding) {
  var usableWidth = Math.max(1, width - padding * 2)
  var usableHeight = Math.max(1, height - padding * 2)
  var ratio = Math.min(usableWidth / area.width, usableHeight / area.height)
  var originX = padding + (usableWidth - area.width * ratio) / 2
  var originY = padding + (usableHeight - area.height * ratio) / 2
  return {
    x: originX + (monitor.x - area.x) * ratio,
    y: originY + (monitor.y - area.y) * ratio,
    width: monitor.width * ratio,
    height: monitor.height * ratio
  }
}
