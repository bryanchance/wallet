Red [Needs: View]

#include %../libs/int256.red
#include %../libs/btc-api.red
#include %../libs/int-encode.red
#include %../libs/HID/hidapi.red
#include %../keys/keys.red

trezor-id: 1 << 16 or 534Ch
ledger-id: 1 << 16 or 2C97h

devs: reduce [trezor-id (FF01h << 16) trezor-id 2 trezor-id (F1D0h << 16) trezor-id 4 ledger-id 1 ledger-id 2 ledger-id 3]

key/current/devices: devs
probe key/current/name-list

print ["current will be: [trezor 0 1]"]
print [key/current/device-name key/current/device-index key/current/device-enum-index]
key/current/selected: 2
print ["current will be: [trezor 1 3]"]
print [key/current/device-name key/current/device-index key/current/device-enum-index]
key/current/selected: 3
print ["current will be: [ledger 0 0]"]
print [key/current/device-name key/current/device-index key/current/device-enum-index]
key/current/selected: 4
print ["current will be: [ledger 1 1]"]
print [key/current/device-name key/current/device-index key/current/device-enum-index]
key/current/selected: 5
print ["current will be: [ledger 2 2]"]
print [key/current/device-name key/current/device-index key/current/device-enum-index]

print "begin enumerate devices"
devices: key/enumerate
probe devices

key/current/devices: devices
probe key/current
key/current/selected: 1
probe key/current/name-list

if all [key/current/device-name key/current/device-enum-index][
	if key/connect [
		key/init
		view layout [
			t: text "" rate 0:0:1 on-time [
				if 'Init = key/get-request-pin-state [
					key/request-pin
				]
				t/text: form key/get-request-pin-state
				if 'HasRequested = key/get-request-pin-state [
					unview
					exit
				]
				if 'Requesting <> key/get-request-pin-state [
					t/rate: none
				]
			]
		]
	]
]
