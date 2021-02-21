#!/bin/sh

echo 'Remove ipa'
rm -fr ./*.ipa
echo 'Remove Payload Folder'
rm -fr Payload/
echo 'Run delds'
find . -name ".DS_Store" | xargs rm
echo 'Sing binary'
ldid -S./OTADisabler/dimentio/tfp0.plist ./OTADisabler.app/OTADisabler
echo 'Create Payload Folder'
mkdir Payload
echo 'mv OTADisabler.app to Payload Folder'
mv -fv OTADisabler.app/ Payload/
echo 'Create IPA'
zip -r OTADisabler-v0.0.2~beta2.ipa Payload
echo 'done'

exit 0
