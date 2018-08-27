Red [
	Title:	"Driver for Ledger Nano S"
	Author: "Xie Qingtian"
	File: 	%ledger.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_ledger_red_][
#do [_ledger_red_: yes]
#include %../../libs/HID/hidapi.red
#include %../../libs/int-encode.red
#include %../../libs/rlp.red
#include %../../libs/btc-addr.red

ledger: context [
	name: "Ledger Nano S"

	system/catalog/errors/user: make system/catalog/errors/user [ledger: ["ledger [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'ledger [name arg2 arg3]
	]

	vendor-id:			2C97h
	product-id:			1
	ids: reduce [product-id << 16 or vendor-id]

	DEFAULT_CHANNEL:	0101h
	TAG_APDU:			05h
	PACKET_SIZE:		#either config/OS = 'Windows [65][64]
	MAX_APDU_SIZE:		260

	dongle: none
	buffer:		make binary! MAX_APDU_SIZE
	data-frame: make binary! PACKET_SIZE

	request-pin-state: 'Init							;-- Init/Requesting/HasRequested/DeviceError

	btc-coin-version: context [
		payToAddressVersion: none
		payToScriptHashVersion: none
		coinFamily: none
		coinId: none
		shortCoinId: none
	]

	filter?: func [
		_id				[integer!]
		_usage			[integer!]
		return:			[logic!]
	][
		unless find ids _id [return false]
		if (_usage >>> 16) = FF01h [return false]		;-- skip debug integerface
		if (_usage >>> 16) = F1D0h [return false]		;-- skip fido integerface
		true
	]

	support?: func [
		_id				[integer!]
		return:			[logic!]
	][
		if find ids _id [return true]
		false
	]

	open: func [_id [integer!] index [integer!] return: [handle!]][
		unless dongle [
			dongle: hid/open _id index
		]
		dongle
	]

	close: does [
		if dongle <> none [
			hid/close dongle 
			dongle: none
		]
	]

	init: func [unitname [string!] return: [word!] /local res] [
		case [
			any [unitname = "ETH" unitname = "RED"] [
				if string? res: get-eth-public-address [8000002Ch 8000003Ch 80000000h 0 0] [return 'success]
				res
			]
			unitname = "BTC" [
				if string? res: get-btc-public-address [80000031h 80000000h 80000000h 0 0] [
					btc-get-coin-version
					if btc-coin-version/shortCoinId <> unitname [
						return 'app
					]
					return 'success
				]
				res
			]
			unitname = "TEST" [
				if string? res: get-btc-public-address [80000031h 80000001h 80000000h 0 0] [
					btc-get-coin-version
					if btc-coin-version/shortCoinId <> unitname [
						return 'app
					]
					return 'success
				]
				res
			]
			true [
				new-error 'init 'unknown unitname
			]
		]
	]

	close-pin-requesting: does [
		request-pin-state: 'Init
	]

	request-pin: func [return: [word!]] [
		request-pin-state: 'HasRequested
		request-pin-state
	]

	read-apdu: func [
		timeout [integer!]				;-- seconds
		/local idx total msg-len data
	][
		idx: 0
		clear buffer
		until [
			hid/read dongle clear data-frame timeout * 1000

			data: data-frame

			;-- sanity check the frame
			if DEFAULT_CHANNEL <> to-int16 data [
				return copy/part data 4
			]
			if TAG_APDU <> data/3 [
				return buffer
			]
			if idx <> to-int16 skip data 3 [
				return buffer
			]

			;-- extract the message
			data: skip data 5
			if zero? idx [
				total: to-int16 data
				data: skip data 2
			]
			idx: idx + 1

			msg-len: min total length? data

			append/part buffer data msg-len
			total: total - msg-len
			zero? total
		]
		buffer
	]

	write-apdu: func [data [binary!] /local idx limit][
		idx: 0
		while [not empty? data][
			clear data-frame
			append data-frame reduce [	;-- header
				#if config/OS = 'Windows [0]
				to-bin16 DEFAULT_CHANNEL
				TAG_APDU
				to-bin16 idx
			]

			if zero? idx [				;-- first packet's header includes a two-byte length
				append data-frame to-bin16 length? data
			]
			idx: idx + 1

			limit: PACKET_SIZE - length? data-frame
			append/part data-frame data limit
			if PACKET_SIZE <> length? data-frame [
				append/dup data-frame 0 PACKET_SIZE - length? data-frame
			]
			data: skip data limit
			hid/write dongle data-frame
		]
	]

	btc-get-coin-version: has [data full-name-len short-name-len][
		data: copy #{E0 16 00 00 00}
		write-apdu data
		data: read-apdu 1
		if 7 >= length? data [
			new-error 'btc-get-coin-version 'unknown data
		]

		btc-coin-version/payToAddressVersion: data/1 << 8 + data/2
		btc-coin-version/payToScriptHashVersion: data/3 << 8 + data/4
		btc-coin-version/coinFamily: data/5
		full-name-len: data/6
		btc-coin-version/coinId: to string! copy/part skip data 6 full-name-len
		short-name-len: pick skip data 6 + full-name-len 1
		btc-coin-version/shortCoinId: to string! copy/part skip data 7 + full-name-len short-name-len
	]

	get-eth-public-address: func [ids [block!] return: [string! word!] /local data pub-key-len addr-len][
		data: make binary! 20
		append data reduce [
			E0h
			02h
			0
			0
			4 * (length? ids) + 1
		]
		append data collect [
			keep length? ids
			forall ids [keep to-bin32 ids/1]
		]
		write-apdu data
		data: read-apdu 1

		case [
			40 < length? data [
				;-- parse reply data
				pub-key-len: to-integer data/1
				addr-len: to-integer pick skip data pub-key-len + 1 1
				rejoin ["0x" to-string copy/part skip data pub-key-len + 2 addr-len]
			]
			#{BF00018D} = data ['browser-support-on]
			#{6804} = data ['locked]
			#{6700} = data ['plug]
			#{6D00} = data ['app]
			true ['unknown]
		]
	]

	get-eth-address: func [ids [block!] return: [string!]][
		get-eth-public-address ids
	]

	get-btc-public-address: func [ids [block!] return: [block! string! word!] /all /local segwit? data pub-key-len pub-key addr-len ret][
		segwit?: false
		if ids/1 = (80000000h + 49) [
			segwit?: true
		]

		data: make binary! 20
		append data reduce [
			E0h
			40h
			0
			either segwit? [1][0]
			4 * (length? ids) + 1
		]
		append data collect [
			keep length? ids
			forall ids [keep to-bin32 ids/1]
		]
		write-apdu data
		data: read-apdu 1

		case [
			40 < length? data [
				;-- parse reply data
				pub-key-len: to-integer data/1
				pub-key: copy/part skip data 1 pub-key-len
				addr-len: to-integer pick skip data pub-key-len + 1 1
				ret: to-string copy/part skip data pub-key-len + 2 addr-len
				either all [reduce [ret pub-key]][ret]
			]
			#{6804} = data ['locked]
			#{6700} = data ['plug]
			#{6D00} = data ['app]
			true ['unknown]
		]
	]

	get-btc-address: func [ids [block!]][
		get-btc-public-address/all ids
	]

	sign-eth-tx: func [ids [block!] tx [block!] /local chunk max-sz sz signed][
		;-- tx: [nonce, gasprice, startgas, to, value, data]
		tx-bin: rlp/encode tx
		chunk: make binary! 200
		while [not empty? tx-bin][
			clear chunk
			insert/dup chunk 0 5
			max-sz: either head? tx-bin [133][150]
			sz: min max-sz length? tx-bin
			chunk/1: E0h
			chunk/2: 04h
			chunk/3: either head? tx-bin [0][80h]
			chunk/4: 0
			chunk/5: either head? tx-bin [sz + (4 * (length? ids) + 1)][sz]
			if head? tx-bin [
				append chunk collect [
					keep length? ids
					forall ids [keep to-bin32 ids/1]
				]
			]
			append/part chunk tx-bin sz
			write-apdu chunk
			signed: read-apdu 300
			tx-bin: skip tx-bin sz
		]
		if signed = #{6A80} [return 'token-error]
		either 4 > length? signed [none][signed]
	]

	get-eth-signed-data: func [ids tx /local signed][
		signed: sign-eth-tx ids tx
		either all [signed binary? signed][
			append tx reduce [
				copy/part signed 1
				copy/part next signed 32
				copy/part skip signed 33 32
			]
			rlp/encode tx
		][signed]
	]

	get-real-pubkey: func [pubkey [binary!] addr [string!] type [word!] return: [binary!]
		/local xkey
	][
		either pubkey/1 = 4 [
			xkey: head insert copy/part skip pubkey 1 32 2
			if addr = btc-addr/pubkey-to-addr xkey type [
				return xkey
			]
			xkey: head insert copy/part skip pubkey 1 32 3
			if addr = btc-addr/pubkey-to-addr xkey type [
				return xkey
			]
			none
		][
			pubkey
		]
	]

	sign-btc-tx: func [
		tx				[block!]
		return:			[block! binary!]
		/local
			coin_name input-segwit? addr-type data type trust-type
			input-count tx-input tx-output pre-input pre-output ids output-count preout-script
			signed temp pubkey sig-script
	][
		signed: make binary! 800
probe tx
		coin_name: "Bitcoin"
		if tx/inputs/1/path/2 = (80000000h + 1) [
			coin_name: "Testnet"
		]
		input-segwit?: false
		if tx/inputs/1/path/1 = (80000000h + 49) [
			input-segwit?: true
		]

		addr-type: either coin_name = "Bitcoin" [
			either input-segwit? ['P2SH]['P2PKH]
		][
			either input-segwit? ['TEST-P2SH]['TEST-P2PKH]
		]

		data: make binary! 200
		input-count: length? tx/inputs
		tx-input: pick tx/inputs 1
		probe tx-input
		append data temp: to-bin32/little tx-input/info/version
		append data input-count
		append signed temp
		append signed #{0001}
		append signed input-count
		type: either input-segwit? [2][0]
		start-hash-input/first type data

		repeat i input-count [
			tx-input: pick tx/inputs i
			trust-type: either input-segwit? [2][0]
			clear data
			append data trust-type
			append data temp: reverse debase/base tx-input/tx-hash 16
			append signed temp
			repeat j length? tx-input/info/outputs [
				pre-output: pick tx-input/info/outputs j
				if tx-input/addr = pick pre-output/addresses 1 [break]
			]
			append data temp: to-bin32/little j - 1
			append signed temp
			append signed #{1716}
			pubkey: get-real-pubkey tx-input/pubkey tx-input/addr addr-type
			append signed btc-addr/pubkey-to-script pubkey
			append data reverse skip i256-to-bin pre-output/value 24
			;-- #{00}: place holder for sign
			append data #{00}
			start-hash-input type data

			clear data
			;append data temp: to-bin32/little select tx-input/info/inputs/1 'sequence
			append data temp: #{FFFFFF00}
			append signed temp
			start-hash-input type data
		]

		clear data
		ids: select last tx/outputs 'path
		append data collect [
			keep length? ids
			forall ids [keep to-bin32 pick ids 1]
		]
		final-hash-input FFh data

		probe tx/outputs
		clear data
		output-count: length? tx/outputs
		append data output-count
		repeat i output-count [
			tx-output: pick tx/outputs i
			append data reverse skip i256-to-bin tx-output/value 24
			append data #{17 A9 14}
			append data copy/part skip debase/base tx-output/addr 58 1 20
			append data #{87}
		]
		append signed data
		probe data
		while [50 < length? data][
			final-hash-input 0 copy/part data 50
			data: skip data 50
		]
		final-hash-input 80h data

		type: 80h
		print ["num: " input-count]
		repeat i input-count [
			print i
			tx-input: pick tx/inputs i
			trust-type: either input-segwit? [2][0]
			clear data
			append data to-bin32/little tx-input/info/version
			append data 1
			start-hash-input/first type data

			clear data
			append data trust-type
			append data reverse debase/base tx-input/tx-hash 16
			repeat j length? tx-input/info/outputs [
				pre-output: pick tx-input/info/outputs j
				if tx-input/addr = pick pre-output/addresses 1 [break]
			]
			append data to-bin32/little j - 1
			append data reverse skip i256-to-bin pre-output/value 24
			pubkey: get-real-pubkey tx-input/pubkey tx-input/addr addr-type
			sig-script: rejoin [#{76 A9 14} btc-addr/hash160 pubkey #{88 AC}]
			append data length? sig-script

			start-hash-input type data
			clear data
			append data sig-script
			;append data to-bin32/little select tx-input/info/inputs/1 'sequence
			append data #{FFFFFF00}
			start-hash-input type data

			clear data
			ids: tx-input/path
			append data collect [
				keep length? ids
				forall ids [keep to-bin32 pick ids 1]
			]
			append data 0
			append data to-bin32 tx-input/info/lock_time
			append data 1
			append signed 2
			temp: sign-untrusted-hash data
			poke temp 1 temp/1 and FEh
			append signed length? temp
			append signed temp
			append signed length? pubkey
			append signed pubkey
		]

		append signed #{00000000}
		probe signed
		signed
	]

	get-btc-signed-data: func [
		tx			[block!]
	][
		sign-btc-tx tx
	]

	start-hash-input: func [type [integer!] data [binary!] /first
		/local chunk
	][
		chunk: make binary! 200
		append chunk reduce [
			E0h
			44h
			either first [0][80h]
			type
			length? data
		]
		append chunk data
		write-apdu chunk
		chunk: read-apdu 50
		if chunk <> #{9000} [new-error 'start-hash-input "unknown" chunk]
	]

	final-hash-input: func [type [integer!] data [binary!] return: [binary!]
		/local chunk
	][
		chunk: make binary! 200
		append chunk reduce [
			E0h
			4Ah
			type
			0
			length? data
		]
		append chunk data
		write-apdu chunk
		chunk: read-apdu 50
		if 2 > length? chunk [new-error 'final-hash-input "too short" chunk]
		if #{9000} <> back back tail chunk [new-error 'final-hash-input "unknown" chunk]
		copy/part chunk (length? chunk) - 2
	]

	sign-untrusted-hash: func [data [binary!]
		/local chunk sw
	][
		chunk: make binary! 200
		append chunk reduce [
			E0h
			48h
			0
			0
			length? data
		]
		append chunk data
		write-apdu chunk
		chunk: read-apdu 50
		if 2 > length? chunk [new-error 'sign-untrusted-hash "too short" chunk]
		if #{9000} <> back back tail chunk [new-error 'sign-untrusted-hash "unknown" chunk]
		copy/part chunk (length? chunk) - 2
	]
]

]
