# {.push raises: [].}
import std/os
import std/strformat
import std/math
import std/strutils
import std/asyncdispatch
import std/httpclient
import ./hgt


type HgtTileset* = object
  cache*: int = 128
  pwd*: string = "skadi"


const S3Url = "https://elevation-tiles-prod.s3.amazonaws.com/skadi"


proc initHgtTileset*(dir: string): HgtTileset {.raises: [].} =
  let tileset = HgtTileset(pwd: dir)
  return tileset


proc getTileFilePath(lat, lng: float): string {.raises: [].} =
  let latAbs = lat.abs().floor().toInt()
  let latPref = if lat < 0: "S" else: "N"
  let latName = fmt"{latAbs}".align(2, '0')
  let latFileName = fmt"{latPref}{latName}"

  let lonAbs = lng.abs().floor().toInt()
  let lonPref = if lng < 0: "W" else: "E"
  let lonName = fmt"{lonAbs}".align(3, '0')
  let lngFileName = fmt"{lonPref}{lonName}"

  let fileName = fmt"{latFileName}{lngFileName}.hgt.gz"
  return fmt"{latFileName}/{fileName}"


proc getTile(ts: HgtTileset, lat, lng: float): Future[string] {.async.} =
  var file: File
  try:
    let tilePath = getTileFilePath(lat, lng)
    let pDir = tilePath.parentDir()
    let filePath = ts.pwd / tilePath

    if filePath.fileExists():
      return filePath
    else:
      let tileDir = ts.pwd / pDir
      if not tileDir.dirExists():
        tileDir.createDir()
      # download file
      let url = fmt"{S3Url}/{tilePath}"
      let client = newAsyncHttpClient()
      let res = await client.getContent(url)
      file = open(filePath, fmWrite)
      file.write(res)
      return filePath
  except Exception as e:
    echo e.repr
  finally:
    file.close()


proc getElevation*(tileset: HgtTileset, lat, lon: float): int {.raises: [].} =
  try:
    let tilePath = waitFor tileset.getTile(lat, lon)
    return tilePath.hgtGetElevation(lat, lon)
  except Exception as e:
    echo e.repr
    return -32768


proc getElevationAsync*(tileset: HgtTileset, lat, lon: float): Future[
    int] {.async.} =
  try:
    let tilePath = await tileset.getTile(lat, lon)
    return tilePath.hgtGetElevation(lat, lon)
  except Exception as e:
    echo e.repr
    return -32768


proc getElevation*(tileset: HgtTileset, locations: seq[seq[float]]): seq[
    int] {.raises: [].} =
  try:
    var results: seq[Future[int]]
    for loc in locations:
      let res = tileset.getElevationAsync(loc[1], loc[0])
      results.add res
    result = waitFor all(results)
  except Exception as e:
    echo e.repr

when isMainModule:
  assert getTileFilePath(51.3, 13.4) == "N51/N51E013.hgt.gz"
  let tileset = initHgtTileset(dir = getCurrentDir() / "skadi")
  # echo tileset.repr
  # let tilePath = waitFor tileset.getTile(51.3, 13.4)
  echo tileset.getElevation(51.3, 13.4)
  echo tileset.getElevation(45.9689, 14.2999)
  echo tileset.getElevation(45.9715, 14.2515)
  echo tileset.getElevation(@[@[14.2515, 45.9715], @[13.4, 51.3]])


