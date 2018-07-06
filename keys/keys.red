Red [
	Title:	"Driver for Multiple devices"
	Author: "bitbegin"
	File: 	%keys.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#do [_keys_red_: yes]
#if error? try [_ledger_red_] [#include %Ledger/ledger.red]
#if error? try [_trezor_red_] [#include %Trezor/trezor.red]

key: context [

	system/catalog/errors/user: make system/catalog/errors/user [key: ["key [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'key [name arg2 arg3]
	]

	no-dev: "<No Device>"
	_name-list: []
	dongle: none

	support?: func [
		id			[integer!]
		return:		[logic!]
	][
		if find ledger/ids id [return true]
		if find trezor/ids id [return true]
		false
	]

	opened?: func [return: [logic!]] [
		if dongle [return true]
		false
	]

	enumerate: func [return: [block!] /local ids] [
		ids: append copy ledger/ids trezor/ids
		hid/enumerate ids
	]

	free-enumeration: does [hid/free-enumeration]

	parse-devices: func [devices [block!] return: [block!]
		/local blk list len i id usg tag uniq enum-index info info2 index
	][
		;- item [name [id index enum-index]]
		list: copy []
		;- item [[name id] [usg enum-index]]
		blk: copy []

		len: length? devices
		if len = 0 [append list reduce [no-dev [none none none]] return list]
		i: 1
		until [
			id: devices/(i)
			usg: devices/(i + 1)
			case [
				ledger/support? id [
					tag: reduce [ledger/name id]
					uniq: select/only/last blk tag
					either uniq [enum-index: uniq/2 + 1][enum-index: 0]
					append blk reduce [tag reduce [usg enum-index]]
				]
				trezor/support? id [
					tag: reduce [trezor/name id]
					uniq: select/only/last blk tag
					either uniq [enum-index: uniq/2 + 1][enum-index: 0]
					append blk reduce [tag reduce [usg enum-index]]
				]
			]

			i: i + 2
			i > len
		]

		len: length? blk
		if len = 0 [append list reduce [no-dev [none none none]] return list]
		i: 1
		until [
			uniq: blk/(i)
			info: blk/(i + 1)
			case [
				ledger/name = uniq/1 [
					if ledger/filter? uniq/2 info/1 [
						info2: select/last list ledger/name
						either info2 [index: info2/2 + 1][index: 0]
						append list reduce [ledger/name reduce [uniq/2 index info/2]]
					]
				]
				trezor/name = uniq/1 [
					if trezor/filter? uniq/2 info/1 [
						info2: select/last list trezor/name
						either info2 [index: info2/2 + 1][index: 0]
						append list reduce [trezor/name reduce [uniq/2 index info/2]]
					]
				]
			]
			i: i + 2
			i > len
		]
		list
	]

	get-name-list: func [infos [block!] return: [block!]
		/local len i name uniq
	][
		len: length? infos
		if len = 0 [return reduce [no-dev]]
		i: 1
		clear _name-list
		until [
			name: infos/(i)
			uniq: infos/(i + 1)
			either uniq/2 = 0 [
				append _name-list name
			][
				append _name-list rejoin [name ": " to string! uniq/2]
			]
			i: i + 2
			i > len
		]
		_name-list
	]

	current: make reactor! [
		devices: []
		selected: 1
		infos: is [parse-devices devices]
		name-list: is [get-name-list infos]
		count: is [length? name-list]
		device-name: is [pick infos selected * 2 - 1]
		device-info: is [pick infos selected * 2]
		device-id: is [pick device-info 1]
		device-index: is [pick device-info 2]
		device-enum-index: is [pick device-info 3]
	]

	connect: does [
		case [
			current/device-name = ledger/name [ledger/connect current/device-id current/device-enum-index]
			current/device-name = trezor/name [trezor/connect current/device-id current/device-enum-index]
			true [none]
		]
	]

	close: does [
		case [
			current/device-name = ledger/name [ledger/close]
			current/device-name = trezor/name [trezor/close]
		]
		dongle: none
	]

	init: does [
		case [
			current/device-name = ledger/name [ledger/init]
			current/device-name = trezor/name [trezor/init]
		]
	]

	get-request-pin-state: func [return: [word!]] [
		case [
			current/device-name = trezor/name [trezor/request-pin-state]
			true ['HasRequested]
		]
	]

	request-pin: func [mode [word!] return: [word!]][
		case [
			current/device-name = trezor/name [trezor/request-pin mode]
			true ['HasRequested]
		]
	]

	close-pin-requesting: does [
		case [
			current/device-name = trezor/name [trezor/close-pin-requesting]
			true []
		]
	]

	get-eth-address: func [bip32-path [block!]][
		case [
			current/device-name = ledger/name [ledger/get-eth-address bip32-path]
			current/device-name = trezor/name [trezor/get-eth-address bip32-path]
			true ['NotSupport]
		]
	]

	get-btc-address: func [bip32-path [block!]][
		case [
			current/device-name = trezor/name [trezor/get-btc-address bip32-path]
			true ['NotSupport]
		]
	]

	get-eth-signed-data: func [
		bip32-path				[block!]
		tx						[block!]
	][
		case [
			current/device-name = ledger/name [ledger/get-eth-signed-data bip32-path tx]
			current/device-name = trezor/name [trezor/get-eth-signed-data bip32-path tx]
			true ['NotSupport]
		]
	]

	get-btc-signed-data: func [
		tx						[block!]
	][
		case [
			current/device-name = trezor/name [trezor/get-btc-signed-data tx]
			true ['NotSupport]
		]
	]
]
