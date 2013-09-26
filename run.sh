#!/usr/bin/env bash

source ~/.rvm/scripts/rvm

rvm use system

LC_NUMERIC=C taskset 1 ruby test.rb

