#!/bin/bash

cd $( dirname "${BASH_SOURCE[0]}" )

# Update Calibre plugin if it is installed on host
if [ ! -z "$(calibre-customize -l | grep 'InputOSIS')" ]; then calibre-customize -b ./calibre_plugin/OSIS-Input; fi

# Updates any Virtual Machine by running VagrantProvision.sh on it
if [ ! -z "$(vagrant status | grep 'not created')" ]; then exit; fi
if [ "$(grep 'Module-tools' Vagrantshares)" != "" ]; then
  sed -i '/Module-tools/d' Vagrantshares
  if [ "$(vagrant status | grep 'The VM is running')" != "" ]; then vagrant halt; fi
fi

if [ "$(vagrant status | grep 'The VM is running')" == "" ]; then vagrant up; fi

vagrant provision
