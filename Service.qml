pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var manifest: null
  property var shell: null

  readonly property int contractVersion: 1
  readonly property bool ready: true

  property var movies: []
  property var theaters: []
  property bool loading: false
  property bool searchingTheaters: false
  property string error: ""
  property date lastFetch: new Date(0)

  property string theaterId: "6952"
  property string theaterName: "Cinemark Sierra Vista 10"
  property string theaterZip: ""

  readonly property string configDir: Quickshell.env("HOME") + "/.config/now-playing"
  readonly property string configFile: configDir + "/config.json"
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/now-playing"
  readonly property string cacheFile: cacheDir + "/data.json"
  readonly property int refreshIntervalMs: 43200000

  // --- Processes ---

  Process {
    id: fetchProcess
    command: ["curl", "-s", "-L", "--max-time", "15",
              "https://www.bigscreen.com/Marquee.php?theater=" + root.theaterId]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (data.trim().length > 0) root.htmlBuffer += data
      }
    }
    onRunningChanged: {
      if (!running) {
        if (root.htmlBuffer.length > 0) {
          root.parseHtml(root.htmlBuffer)
          root.htmlBuffer = ""
          root.loading = false
          root.lastFetch = new Date()
          root.saveCache()
        } else {
          root.loading = false
          root.error = "No data received"
        }
      }
    }
  }

  property string htmlBuffer: ""

  Process {
    id: searchProcess
    command: ["curl", "-s", "-L", "--max-time", "15",
              "https://www.bigscreen.com/Marquee.php?action=chloc&view=nearby&zip=" + root.pendingZip]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (data.trim().length > 0) root.searchBuffer += data
      }
    }
    onRunningChanged: {
      if (!running) {
        root.parseTheaters(root.searchBuffer)
        root.searchBuffer = ""
        root.searchingTheaters = false
      }
    }
  }

  property string searchBuffer: ""
  property string pendingZip: ""

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.cacheDir]
    running: false
  }

  Process {
    id: mkdirConfigProc
    command: ["mkdir", "-p", root.configDir]
    running: false
  }

  // --- Cache file reader ---

  FileView {
    id: cacheFileView
    path: root.cacheFile
    watchChanges: false
    printErrors: false
    blockLoading: true
    onLoaded: {
      var content = cacheFileView.text()
      if (content && content.length > 0) {
        try {
          var parsed = JSON.parse(content)
          root.movies = parsed.movies || []
          root.lastFetch = new Date(parsed.timestamp || 0)
        } catch (e) {}
      }
    }
  }

  // --- Config file reader ---

  FileView {
    id: configFileView
    path: root.configFile
    watchChanges: false
    printErrors: false
    blockLoading: true
    onLoaded: {
      var content = configFileView.text()
      if (content && content.length > 0) {
        try {
          var cfg = JSON.parse(content)
          if (cfg.theaterId) root.theaterId = cfg.theaterId
          if (cfg.theaterName) root.theaterName = cfg.theaterName
          if (cfg.theaterZip) root.theaterZip = cfg.theaterZip
        } catch (e) {}
      }
    }
  }

  // --- Timer ---

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Init ---

  Component.onCompleted: {
    mkdirProc.running = true
    mkdirConfigProc.running = true
    configFileView.reload()
    cacheFileView.reload()
    Qt.callLater(function() {
      if (root.movies.length === 0 || root.isExpired()) {
        root.refresh()
      }
    })
  }

  // --- Public API ---

  function refresh() {
    if (root.loading) return
    root.loading = true
    root.error = ""
    root.htmlBuffer = ""
    fetchProcess.running = true
  }

  function searchByZip(zip) {
    if (root.searchingTheaters || !zip) return
    root.searchingTheaters = true
    root.searchBuffer = ""
    root.pendingZip = zip.trim()
    searchProcess.running = true
  }

  function selectTheater(id, name) {
    root.theaterId = id
    root.theaterName = name
    root.theaters = []
    saveConfig()
    root.lastFetch = new Date(0)
    root.refresh()
  }

  function isExpired() {
    return (new Date() - root.lastFetch) > root.refreshIntervalMs
  }

  // --- Internal ---

  function saveCache() {
    var data = {
      timestamp: new Date().toISOString(),
      movies: root.movies
    }
    cacheFileView.setText(JSON.stringify(data, null, 2))
  }

  function saveConfig() {
    var cfg = {
      theaterId: root.theaterId,
      theaterName: root.theaterName,
      theaterZip: root.theaterZip
    }
    configFileView.setText(JSON.stringify(cfg, null, 2))
  }

  function parseTheaters(html) {
    var result = []
    var re = /theater=(\d+)[^"]*"[^>]*>([^<]+)/g
    var m
    var seen = {}
    while ((m = re.exec(html)) !== null) {
      var id = m[1]
      var name = m[2].trim()
      if (!seen[id] && name.length > 2) {
        seen[id] = true
        result.push({ id: id, name: name })
      }
    }
    root.theaters = result
  }

  function parseHtml(html) {
    var result = []

    var tableStart = html.indexOf('class="sched_box"')
    if (tableStart < 0) { movies = result; return }
    var tableHtml = html.substring(tableStart)

    var rows = tableHtml.split(/<tr[^>]*>/i)
    var currentMovie = null

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]

      var titleMatch = row.match(/class="movieNameList"[^>]*>([^<]+)/i)
      if (titleMatch) {
        if (currentMovie && currentMovie.title) {
          result.push(currentMovie)
        }
        currentMovie = {
          title: titleMatch[1].trim(),
          id: "",
          poster: "",
          rating: "",
          runtime: "",
          showtimes: []
        }
        var idMatch = row.match(/movie=(\d+)/)
        if (idMatch) currentMovie.id = idMatch[1]
      }

      if (!currentMovie) continue

      var posterMatch = row.match(/src="([^"]+)"[^>]*class="moviegraphic_list"/i)
      if (posterMatch && !currentMovie.poster) currentMovie.poster = posterMatch[1]

      var ratingMatch = row.match(/class="mpaa_rating_letter"[^>]*>([^<]+)/i)
      if (ratingMatch && !currentMovie.rating) currentMovie.rating = ratingMatch[1].trim()

      var runtimeMatch = row.match(/Running Time:\s*(\d+:\d+)/i)
      if (runtimeMatch && !currentMovie.runtime) currentMovie.runtime = runtimeMatch[1]

      var stMatch = row.match(/class="col_showtimes"[\s\S]*?<\/td>/i)
      if (stMatch) {
        var stBlock = stMatch[0]
        var re2 = />(\d{1,2}:\d{2}[ap]?)</gi
        var tm
        while ((tm = re2.exec(stBlock)) !== null) {
          var time = tm[1].trim()
          if (time && currentMovie.showtimes.indexOf(time) < 0) {
            currentMovie.showtimes.push(time)
          }
        }
      }
    }

    if (currentMovie && currentMovie.title) {
      result.push(currentMovie)
    }

    movies = result
  }
}
