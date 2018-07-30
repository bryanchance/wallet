Red [
	Title:	"Driver for Multiple devices"
	Author: "bitbegin"
	File: 	%keys.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_keys_red_][
#do [_keys_red_: yes]
#include %Ledger/ledger.red
#include %Trezor/trezor.red

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
		if len = 0 [return append list reduce [no-dev reduce [none none none]]]
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
		if len = 0 [return append list reduce [no-dev reduce [none none none]]]
		i: 1
		until [
			uniq: blk/(i)
			info: blk/(i + 1)
			case [
				ledger/name = uniq/1 [
					if ledger/filter? ui-type uniq/2 info/1 [
						info2: select/last list ledger/name
						either info2 [index: info2/2 + 1][index: 0]
						append list reduce [ledger/name reduce [uniq/2 index info/2]]
					]
				]
				trezor/name = uniq/1 [
					if trezor/filter? ui-type uniq/2 info/1 [
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
		clear _name-list
		len: length? infos
		if len = 0 [return append _name-list no-dev]
		i: 1
		until [
			name: infos/(i)
			uniq: infos/(i + 1)
			either any [uniq/2 = none uniq/2 = 0] [
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
		device-id: is [either device-info [pick device-info 1][none]]
		device-index: is [either device-info [pick device-info 2][none]]
		device-enum-index: is [either device-info [pick device-info 3][none]]
	]

	set 'device-name does [current/device-name]
	set 'device-id does [current/device-id]
	set 'device-enum-index does [current/device-enum-index]
	set 'select-device func [index [integer!] return: [integer!]][
		if index > current/count [index: current/count]
		if index < 1 [index: 1]
		current/selected: index
		index
	]

	open: func [return: [handle!]] [
		if any [device-name = none device-id = none device-enum-index = none][return dongle: none]
		dongle: case [
			device-name = ledger/name [ledger/open device-id device-enum-index]
			device-name = trezor/name [trezor/open device-id device-enum-index]
			true [new-error 'open "not found" device-name]
		]
		dongle
	]

	close: does [
		close-pin-requesting
		ledger/close
		trezor/close
		dongle: none
	]

	init: does [
		case [
			device-name = ledger/name [ledger/init]
			device-name = trezor/name [trezor/init]
			true [new-error 'init "not found" device-name]
		]
	]

	get-request-pin-state: func [return: [word!]] [
		case [
			device-name = ledger/name [ledger/request-pin-state]
			device-name = trezor/name [trezor/request-pin-state]
			true [new-error 'get-request-pin-state "not found" device-name]
		]
	]

	request-pin: func [ui-type [string!] return: [word!]][
		case [
			device-name = ledger/name [ledger/request-pin ui-type]
			device-name = trezor/name [trezor/request-pin ui-type]
			true [new-error 'request-pin "not found" device-name]
		]
	]

	close-pin-requesting: does [
		ledger/close-pin-requesting
		trezor/close-pin-requesting
	]

	get-eth-address: func [bip32-path [block!]][
		case [
			device-name = ledger/name [ledger/get-eth-address bip32-path]
			device-name = trezor/name [trezor/get-eth-address bip32-path]
			true [new-error 'get-eth-address "not found" device-name]
		]
	]

	get-btc-address: func [bip32-path [block!]][
		case [
			device-name = ledger/name [ledger/get-btc-address bip32-path]
			device-name = trezor/name [trezor/get-btc-address bip32-path]
			true [new-error 'get-eth-address "not found" device-name]
		]
	]

	get-eth-signed-data: func [
		bip32-path				[block!]
		tx						[block!]
		chain-id				[integer!]
	][
		case [
			device-name = ledger/name [ledger/get-eth-signed-data bip32-path tx]
			device-name = trezor/name [trezor/get-eth-signed-data bip32-path tx chain-id]
			true [new-error 'get-eth-address "not found" device-name]
		]
	]

	get-btc-signed-data: func [
		tx						[block!]
	][
		case [
			device-name = trezor/name [trezor/get-btc-signed-data tx]
			true [new-error 'get-eth-address "not found" device-name]
		]
	]
]

]
