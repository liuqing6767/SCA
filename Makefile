# make, make all
all: prepare gen push

prepare:
	git submodule init
	git submodule update

gen: prepare
	cd _gen && hugo -d /tmp/hugo_docs

push:
	git checkout pages
	rm -rf ./*
	mv /tmp/hugo_docs/* ./
	git add .
	git commit -m 'auto submit'
	git push origin pages
	git checkout master

run:
	hugo serve