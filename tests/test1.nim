import unittest
import os
import elevations
import hgt
import elevations

test "get elevation from compressed and uncompressed file":
  let path1 = getCurrentDir() / "tests" / "N51" / "N51E013.hgt"
  let path = getCurrentDir() / "tests" / "N51" / "N51E013.hgt.gz"
  check hgtGetElevation(path1, 51.3, 13.4) == 101
  check hgtGetElevation(path, 51.3, 13.4) == 101

test "tileset":
  let tileset = initHgtTileset(dir = getCurrentDir() / "skadi")
  let ele = tileset.getElevation(45.9715, 14.2515)
  check ele == 733

test "tileset elevations":
  let tileset = initHgtTileset(dir = getCurrentDir() / "skadi")
  let eles = tileset.getElevation(@[@[14.2515, 45.9715], @[13.4, 51.3]])
  check eles == @[733, 101]
