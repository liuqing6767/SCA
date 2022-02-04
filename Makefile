# make, make all
all: clean gen

clean:
	rm -rf docs

gen: clean
	hugo -D
	mv public docs

run:
	hugo serve