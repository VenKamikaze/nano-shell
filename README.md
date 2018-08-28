# nano-shell
Nano Node bash convenience wrapper

WARNING: Do not use this script on the real nano network. It is intended for testing purposes on the beta nano network.
I cannot be held responsible for any loss of funds resulting in the use of this script.

## Basic Usage

Download the script:
wget  https://raw.githubusercontent.com/VenKamikaze/nano-shell/master/nano-functions.bash

Source it into your shell:
source ./nano-functions.bash

And start using it!

Note: if you have trouble reaching your node RPC, make sure you have the RPC enabled in your Node's config.json file. Then make sure that the NODEHOST variable in 'nano-functions.bash' is pointing at the RPC address and port.

## Compatibility

* Most Linux Distros (make sure you pay attention to any dependency check errors and install necessary packages)
* Ubuntu Shell in Windows 10

