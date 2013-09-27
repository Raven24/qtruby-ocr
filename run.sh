#!/usr/bin/env bash

source ~/.rvm/scripts/rvm

rvm --create use 1.9.3@qtruby-ocr

bundle install

LC_NUMERIC=C taskset 1 ruby test.rb

