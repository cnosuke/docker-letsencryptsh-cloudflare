#!/bin/bash
cd `dirname $0`

bundle exec ruby ./hook.rb $@
