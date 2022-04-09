#!/usr/bin/env bash

#install bats libs in current folder /lib

mkdir bash/lib
cd bash/lib

curl -L -O -J https://github.com/bats-core/bats-core/archive/refs/tags/v1.6.0.tar.gz 
tar -zxvf bats-core-1.6.0.tar.gz
mv bats-core-1.6.0 bats-core

curl -L -O -J https://github.com/bats-core/bats-support/archive/v0.3.0.tar.gz
tar -zxvf bats-support-0.3.0.tar.gz
mv bats-support-0.3.0 bats-support

curl -L -O -J https://github.com/bats-core/bats-assert/archive/v2.0.0.tar.gz
tar -zxvf bats-assert-2.0.0.tar.gz
mv bats-assert-2.0.0 bats-assert

curl -L -O -J https://github.com/bats-core/bats-file/archive/refs/tags/v0.3.0.tar.gz
tar -zxvf bats-file-0.3.0.tar.gz
mv bats-file-0.3.0 bats-file
