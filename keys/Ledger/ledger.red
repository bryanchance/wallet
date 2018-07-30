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

	pin-ret: none
	request-pin-state: 'Init							;-- Init/Requesting/HasRequested/DeviceError

	filter?: func [
		_id				[integer!]
		_usage			[integer!]
		return:			[logic!]
	][
		if find ids _id [return true]
		false
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

	init: does [
		request-pin-state: 'Init
	]

	close-pin-requesting: does [
		if request-pin-state = 'Requesting [
			request-pin-state: 'Init
			unview/only unlock-dev-dlg
		]
	]

	request-pin: func [return: [word!]] [
		if request-pin-state <> 'Init [return request-pin-state]
		request-pin-state: 'Requesting
		if string? pin-ret: get-eth-address [8000002Ch 8000003Ch 80000000h 0 0] [
			request-pin-state: 'HasRequested
			return request-pin-state
		]
		view/no-wait/flags unlock-dev-dlg 'modal
		request-pin-state
	]

	unlock-dev-dlg: layout [
		title "Unlock your key"
		text font-size 12 {Unlock your Ledger key, open the Ethereum app, ensure "Browser support" is "No".} rate 0:0:3 on-time [
			if string? pin-ret: get-eth-address [8000002Ch 8000003Ch 80000000h 0 0] [
				request-pin-state: 'HasRequested
				unview
				exit
			]
			if 'locked <> pin-ret [
				request-pin-state: 'DeviceError
				unview
				exit
			]
		]
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

	get-eth-address: func [ids [block!] /local data pub-key-len addr-len][
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
		]
	]

	sign-eth-tx: func [ids [block!] tx [block!] /local data max-sz sz signed][
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
]

]
