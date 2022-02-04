# make, make all
all: clean gen push

clean:
	rm -rf docs

gen: clean
	hugo -D
	mv public docs

run:
	hugo serve

push:
	git add .
	git commit --amend -q
	git push origin master
