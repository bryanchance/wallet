Red [Needs: View]

#if error? try [_int256_red_] [#include %../libs/int256.red]
#if error? try [_btc-api_red_] [#include %../libs/btc-api.red]
#if error? try [_int-encode_red_] [#include %../libs/int-encode.red]
#if error? try [_hidapi_red_] [#include %../libs/HID/hidapi.red]
#if error? try [_keys_red_] [#include %../keys/keys.red]

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
