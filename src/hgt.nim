# versions 1 is the semi raw data
# 2.1 is non-void filled
# 3 (SRTM Plus) is void-filled

# 1-arc second (30 meters) or 3-arc seconds (90 meters) and are divided into 1°×1° data tiles.

# distributed as a zipped file in *.hgt format.
# The filename of the *.hgt file is labeled with the coordinate of the southwest (bottom left corner) cell.
# For example, the file N45W122.hgt contains data from 45°N to 46°N and from 122°E to 123°E inclusive.

# HGT files are big endian byte order
# The DEM is provided as 16-bit signed integer data in a simple binary raster.
# Since they are signed integers elevations can range from -32767 to 32767
# These data also contain occassional voids from a number of causes such as shadowing,
# phase unwrapping anomalies, or other radar-specific causes. Voids are flagged with the value -32768.
# The DEM data are provided in Motorola or IEEE byte order, which stores the most significant byte first ("big endian")

# There are no header or trailer bytes embedded in the file.
# The data are stored in row major order (all the data for row 1, followed by all the data for row 2, etc.).

# All elevations are in meters referenced to the WGS84/EGM96 geoid
# as documented at http://www.NGA.mil/GandG/wgsegm/.

# https://gis.stackexchange.com/questions/43743/extracting-elevation-from-hgt-file

{.push raises: [].}
import std/os
import std/endians
import std/math
import std/strutils
import pkg/zippy
import pkg/zippy/tarballs
import pkg/zippy/gzip

proc getElvVal(file: File, row, col, size: int): int16 =
  try:
    let offset = ((size - row - 1) * size + col) * 2
    file.setFilePos(offset)
    var buffer = newString(2)
    let bytesRead = file.readBuffer(buffer[0].addr, 2)
    if bytesRead == 2:
      var value: int16
      bigEndian16(value.addr, buffer[0].addr)
      return value
  except:
    return -32768


proc getElvVal(buffer: string, row, col, size: int): int16 =
  try:
    let offset = ((size - row - 1) * size + col) * 2
    let offsetEnd = offset + 3
    let slice = buffer[offset..offsetEnd]
    var value: int16
    bigEndian16(value.addr, slice[0].addr)
    return value
  except:
    return -32768


proc avgElv(v1, v2, f: int): int =
  return v1 + (v2 - v1) * f


proc bilinear(file: File, row, col, size: int): int =
  let rowLow = floor(row.toFloat()).toInt();
  let rowHi = rowLow + 1;
  let rowFrac = row - rowLow;
  let colLow = floor(col.toFloat()).toInt();
  let colHi = colLow + 1;
  let colFrac = col - colLow;
  let v00 = file.getElvVal(rowLow, colLow, size);
  let v10 = file.getElvVal(rowLow, colHi, size);
  let v11 = file.getElvVal(rowHi, colHi, size);
  let v01 = file.getElvVal(rowHi, colLow, size);
  let v1 = avgElv(v00, v10, colFrac);
  let v2 = avgElv(v01, v11, colFrac);
  return avgElv(v1, v2, rowFrac);


proc bilinear(buffer: string, row, col, size: int): int =
  let rowLow = floor(row.toFloat()).toInt();
  let rowHi = rowLow + 1;
  let rowFrac = row - rowLow;
  let colLow = floor(col.toFloat()).toInt();
  let colHi = colLow + 1;
  let colFrac = col - colLow;
  let v00 = buffer.getElvVal(rowLow, colLow, size);
  let v10 = buffer.getElvVal(rowLow, colHi, size);
  let v11 = buffer.getElvVal(rowHi, colHi, size);
  let v01 = buffer.getElvVal(rowHi, colLow, size);
  let v1 = avgElv(v00, v10, colFrac);
  let v2 = avgElv(v01, v11, colFrac);
  return avgElv(v1, v2, rowFrac);


proc hgtGetElevation*(filename: string, lat, lon: float): int =
  var fhandle: File
  try:
    let isCompressed = filename.endsWith(".gz")
    fhandle = open(filename, fmRead)

    var buffer: string
    var fileSize: int
    if isCompressed:
      let compressedBuffer = fhandle.readAll()
      buffer = uncompress(compressedBuffer)
      fileSize = buffer.len
    else:
      fileSize = fhandle.getFileSize()

    var resolution: int
    var size: int

    if fileSize == 12967201 * 2:
      resolution = 1
      size = 3601
    elif fileSize == 1442401 * 2:
      resolution = 3
      size = 1201
    else:
      echo "unknown file format"
      return -32768

    let col = int((lon - floor(lon)) * size.toFloat)
    let row = int((lat - floor(lat)) * size.toFloat)
    if row < 0 or col < 0 or row >= size or col >= size:
      return -32768

    if isCompressed:
      let value = buffer.bilinear(row, col, size)
      return value
    else:
      let value = fhandle.bilinear(row, col, size)
      return value
  except:
    echo getCurrentException().repr
    return -32768
  finally:
    fhandle.close()


when isMainModule:
  let path1 = getCurrentDir() / "tests" / "N51" / "N51E013.hgt"
  let path = getCurrentDir() / "tests" / "N51" / "N51E013.hgt.gz"
  assert hgtGetElevation(path1, 51.3, 13.4) == 101
  assert hgtGetElevation(path, 51.3, 13.4) == 101
  # echo hgtGetElevation(path1, 51.0, 13.0)
  # echo hgtGetElevation(path, 51.0, 13.0)
  # echo hgtGetElevation(path, 45.9689, 14.2999) # cca 292

