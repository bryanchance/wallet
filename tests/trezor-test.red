Red [Needs:	 View]
#if error? try [_int256_red_] [#include %../libs/int256.red]
#if error? try [_btc-api_red_] [#include %../libs/btc-api.red]
#if error? try [_int-encode_red_] [#include %../libs/int-encode.red]
#if error? try [_hidapi_red_] [#include %../libs/HID/hidapi.red]
#if error? try [_trezor-driver_red_] [#include %../keys/Trezor/trezor-driver.red]
#if error? try [_trezor_red_] [#include %../keys/Trezor/trezor.red]


enumerated-devices: hid/enumerate reduce [trezor/id]

probe enumerated-devices

found: false
index: 0
len: length? enumerated-devices
i: 1
until [
	if trezor/filter? enumerated-devices/(i) enumerated-devices/(i + 1) [
		found: true
		break
	]
	index: index + 1
	i: i + 2
	i > len
]

if found [
	if trezor/connect index [
		res: try [trezor/Initialize #()]
		if not error? res [
			trezor/request-pin-state: 'Init
			trezor/request-pin 'no-modal
			probe trezor/request-pin-state
		]
	]
]