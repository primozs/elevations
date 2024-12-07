./bin/hgt:
	# nimble build
	# nim c -d:release --mm:orc -d:danger --passC:-flto --passC:-march=native -o=bin/igcstats src/igcstats.nim
	nim c -r -o=bin/hgt src/hgt.nim

clean:
	rm -rf ./bin/hgt
