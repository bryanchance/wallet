Red [
	Title:	"Driver for Trezor"
	Author: "bitbegin"
	File: 	%trezor.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#include %trezor-message.red

trezor: context [
	name: "Trezor"

	vendor-id:			534Ch
	product-id:			1
	id: product-id << 16 or vendor-id

	dongle: none
	hid-version: 0
	data-frame: make binary! 65
	command-buffer: make binary! 1000
	error: make block! 10
	msg-id: 0
	pin-get: make string! 16
	pin-msg: none
	pin-req: none
	pin-ret: -1
	request-pin-state: 'Init							;-- Init/Requesting/HasRequested/TrezorError
	serialized_tx: make binary! 500

	filter?: func [
		_id				[integer!]
		_usage			[integer!]
		return:			[logic!]
	][
		if _id <> id [return false]
		if (_usage >>> 16) = FF01h [return false]		;-- skip debug integerface
		if (_usage >>> 16) = F1D0h [return false]		;-- skip fido integerface
		true
	]

	opened?: func [return: [logic!]] [
		if dongle = none [return false]
		true
	]

	close-pin-requesting: does [
		if request-pin-state <> 'Init [
			request-pin-state: 'Init
			unview/only pin-dlg
		]
	]

	request-pin: does [
		if request-pin-state <> 'Init [return request-pin-state]

		pin-req: make map! reduce ['address_n reduce [8000002Ch 8000003Ch 80000000h 0 0]]
		put pin-req 'show_display false
		pin-msg: 'EthereumGetAddress
		clear pin-get
		request-pin-state: 'Requesting

		request-pin-cmd

		if request-pin-state <> 'HasRequested [
			view/no-wait/flags pin-dlg 'modal
		]

		request-pin-state
	]

	request-pin-cmd: func [
		return:		[word!]
		/local
			len		[integer! block!]
	][
		len: encode-and-write pin-msg pin-req
		if block? len [
			request-pin-state: 'TrezorError
			return request-pin-state
		]

		clear command-buffer
		len: message-read command-buffer
		if block? len [
			request-pin-state: 'TrezorError
			return request-pin-state
		]
		if msg-id = trezor-message/get-id 'EthereumAddress [ 
			request-pin-state: 'HasRequested
			return request-pin-state
		]
		if msg-id <> trezor-message/get-id 'PinMatrixRequest [
			request-pin-state: 'TrezorError
			return request-pin-state
		]
	]

	connect: func [index [integer!]][
		unless dongle [
			dongle: hid/open id index
			if dongle <> none [
				hid-version: get-hid-version
			]
		]
		dongle
	]

	set-init: func [return: [block! word!]][
		res: make map! []
		len: Initialize res
		if block? len [return reduce ['InitFailure len]]
		return 'InitSuccess
	]

	get-eth-address: func [
		ids				[block!]
		return:			[binary! block!]
		/local
			res len
	][
		res: make map! []
		len: EthereumGetAddress ids res
		if block? len [
			return reduce ['get-eth-address len]
		]
		if res/address = none [return ['NoneAddress]]
		rejoin ["0x" enbase/base res/address 16]
	]

	get-btc-address: func [
		ids				[block!]
		return:			[binary! block!]
		/local
			res len
			coin-name
			segwit?
	][
		res: make map! []
		coin-name: "Bitcoin"
		if ids/2 = (80000000h + 1) [
			coin-name: "Testnet"
		]
		segwit?: false
		if ids/1 = (80000000h + 49) [
			segwit?: true
		]
		len: GetAddress ids coin-name segwit? res
		if block? len [
			return reduce ['get-btc-address len]
		]
		if res/address = none [return ['NoneAddress]]
		res/address
	]

	get-eth-signed-data: func [
		ids				[block!]
		tx				[block!]
		chain-id		[integer!]
		return:			[block! binary!]
		/local
			req			[map!]
			res			[map!]
			nonce
			gas_price
			gas_limit
			amount
			signed
			len
			data-len
	][
		nonce: trim/head to binary! tx/1
		gas_price: trim/head i256-to-bin tx/2
		gas_limit: trim/head to binary! tx/3
		amount: trim/head i256-to-bin tx/5
		data-len: length? tx/6
		req: make map! reduce [
			'address_n ids
			'nonce nonce 'gas_price gas_price 'gas_limit gas_limit
			'to tx/4 'value amount 'chain_id chain-id
		]
		if data-len > 0 [
			put req 'data_length data-len
			put req 'data_initial_chunk tx/6
		]
		res: make map! []
		len: EthereumSignTx req res
		if block? len [return reduce ['SignError len]]

		append tx reduce [
			to-bin8 res/signature_v
			res/signature_r
			res/signature_s
		]
		rlp/encode tx
	]

	get-btc-signed-data: func [
		tx			[block!]
	][
		SignTxSequence tx
	]

	;===================
	;-- commands
	;===================

	Initialize: func [
		res				[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
	][
		len: encode-and-write 'Initialize #()
		if block? len [return reduce ['Initialize 'Failed len]]
		len: read-and-decode 'Features res
		len
	]

	EthereumGetAddress: func [
		ids				[block!]
		res				[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
			req			[map!]
	][
		req: make map! reduce ['address_n ids]
		put req 'show_display false
		len: PinMatrixSequence 'EthereumGetAddress 'EthereumAddress req res
		len
	]

	EthereumSignTx: func [
		req				[map!]
		res				[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
			res2		[map!]
	][
		len: encode-and-write 'EthereumSignTx req
		if block? len [return reduce ['EthereumSignTx 'SendFailed len]]

		clear command-buffer
		len: message-read command-buffer
		if block? len [return reduce ['EthereumSignTx 'ReadFailed len]]

		if msg-id = trezor-message/get-id 'PinMatrixRequest [
			request-pin-state: 'Requesting
			clear pin-get
			pin-req: req
			pin-msg: 'EthereumSignTx

			view/flags pin-dlg 'modal
		]

		if msg-id <> trezor-message/get-id 'ButtonRequest [return ['EthereumSignTx 'NotButReq]]

		res2: make map! []
		len: proto-encode/decode trezor-message/messages 'ButtonRequest res2 command-buffer
		if block? len [return reduce ['EthereumSignTx 'ButReqDecodeFailed len]]

		len: encode-and-write 'ButtonAck make map! []
		if block? len [return reduce ['EthereumSignTx 'ButAckWrite len]]

		res2: make map! []
		len: read-and-decode 'ButtonRequest res2
		if block? len [return reduce ['EthereumSignTx 'ButReq2Read len]]
		len: encode-and-write 'ButtonAck make map! []
		if block? len [return reduce ['EthereumSignTx 'ButAck2Write len]]

		len: read-and-decode 'EthereumTxRequest res
		len
	]

	SignTxSequence: func [
		tx				[block!]
		return:			[block! binary!]
		/local
			coin_name res-in len req sub-req
			request_type details request_index tx_hash serialized
			tx-input tx-output pre-input pre-output script_type addr-name addr
	][
		clear serialized_tx

		coin_name: "Bitcoin"
		if tx/inputs/1/path/2 = (80000000h + 1) [
			coin_name: "Testnet"
		]
		res-in: make map! []

		;-- first step, send "SignTx" message
		len: SignTx length? tx/outputs length? tx/inputs coin_name 0 res-in
		if block? len [return reduce ['SignTxSequence 'SignTxError len]]

		forever [
			probe res-in
			request_type: select res-in 'request_type
			if request_type = 'TXINPUT [
				details: select res-in 'details
				request_index: select details 'request_index
				tx_hash: select details 'tx_hash
				if all [tx_hash = none request_index <> none] [
					tx-input: tx/inputs/(request_index + 1)
					pre-output: FindOutputByAddr tx-input/info/outputs tx-input/addr
					if integer? pre-output [return reduce ['SignTxSequence 'FindOutputByAddr]]
					script_type: either pre-output/2 = "P2SH" ['SPENDP2SHWITNESS]['SPENDADDRESS]
					sub-req: make map! reduce [
								'address_n tx-input/path
								'prev_hash debase/base tx-input/tx-hash 16
								'prev_index pre-output/1
								'sequence -1
								'script_type script_type]
					if pre-output/2 = "P2SH" [
						put sub-req 'amount trim/head i256-to-bin to-i256 pre-output/3
					]
					req: make map! []
					put req 'inputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					len: WriteAndRead 'TxAck 'TxRequest req res-in
					if block? len [return reduce ['SignTxSequence 'TxAckError 1 len]]
				]
				if all [tx_hash <> none request_index <> none] [
					tx-input: FindInputByTxid tx/inputs tx_hash
					pre-input: tx-input/info/inputs/(request_index + 1)
					sub-req: make map! reduce [
								'prev_hash debase/base pre-input/prev-tx-hash 16
								'prev_index pre-input/prev-position
								'script_sig debase/base pre-input/script-hex 16
								'sequence -1]
					req: make map! []
					put req 'inputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					len: WriteAndRead 'TxAck 'TxRequest req res-in
					if block? len [return reduce ['SignTxSequence 'TxAckError 3 len]]
				]
			]
			
			if request_type = 'TXMETA [
				details: select res-in 'details
				request_index: select details 'request_index
				tx_hash: select details 'tx_hash
				if all [tx_hash <> none request_index = none][
					tx-input: FindInputByTxid tx/inputs tx_hash
					sub-req: make map! reduce [
								'version tx-input/info/version
								'lock_time tx-input/info/lock_time
								'inputs_cnt length? tx-input/info/inputs
								'outputs_cnt length? tx-input/info/outputs]
					req: make map! reduce ['tx sub-req]
					probe req
					len: WriteAndRead 'TxAck 'TxRequest req res-in
					if block? len [return reduce ['SignTxSequence 'TxAckError 2 len]]
				]
			]

			if request_type = 'TXOUTPUT [
				details: select res-in 'details
				serialized: select res-in 'serialized
				request_index: select details 'request_index
				tx_hash: select details 'tx_hash
				if all [tx_hash <> none request_index <> none] [
					tx-input: FindInputByTxid tx/inputs tx_hash
					pre-output: tx-input/info/outputs/(request_index + 1)
					sub-req: make map! reduce [
								'amount trim/head i256-to-bin to-i256 pre-output/value
								'script_pubkey debase/base pre-output/script-hex 16]
					req: make map! []
					put req 'bin_outputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					len: WriteAndRead 'TxAck 'TxRequest req res-in
					if block? len [return reduce ['SignTxSequence 'TxAckError 4 len]]
				]
				if all [tx_hash = none request_index <> none] [
					tx-output: tx/outputs/(request_index + 1)
					either tx-output/path <> none [
						addr-name: 'address_n
						addr: tx-output/path
						either tx-output/path/1 = (80000000h + 49) [
							script_type: 'PAYTOP2SHWITNESS
						][
							script_type: 'PAYTOADDRESS
						]
					][
						addr-name: 'address
						addr: tx-output/addr
						either coin_name = "Bitcoin" [
							either addr/1 = #"3" [
								script_type: 'PAYTOP2SHWITNESS
							][
								script_type: 'PAYTOADDRESS
							]
						][
							either addr/1 = #"2" [
								script_type: 'PAYTOP2SHWITNESS
							][
								script_type: 'PAYTOADDRESS
							]
						]
					]
					sub-req: make map! reduce [
								addr-name addr
								'amount trim/head i256-to-bin tx-output/value
								'script_type script_type]
					req: make map! []
					put req 'outputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					len: WriteAndRead 'TxAck 'TxRequest req res-in
					if msg-id = trezor-message/get-id 'ButtonRequest [
						res-in: make map! []
						len: proto-encode/decode trezor-message/messages 'ButtonRequest res-in command-buffer
						if block? len [return reduce ['SignTxSequence 'ButReqDecodeFailed len]]

						len: encode-and-write 'ButtonAck make map! []
						if block? len [return reduce ['SignTxSequence 'ButAckWrite len]]

						res-in: make map! []
						len: read-and-decode 'TxRequest res-in
						if msg-id = trezor-message/get-id 'ButtonRequest [
							res-in: make map! []
							len: proto-encode/decode trezor-message/messages 'ButtonRequest res-in command-buffer
							if block? len [return reduce ['SignTxSequence 'ButReqDecodeFailed len]]

							len: encode-and-write 'ButtonAck make map! []
							if block? len [return reduce ['SignTxSequence 'ButAckWrite len]]

							res-in: make map! []
							len: read-and-decode 'TxRequest res-in
						]
					]
					if block? len [return reduce ['SignTxSequence 'TxAckError 5 len]]
				]
				if serialized [
					append serialized_tx select serialized 'serialized_tx
					probe serialized_tx
				]
			]
			if request_type = 'TXFINISHED [
				serialized: select res-in 'serialized
				if serialized [
					append serialized_tx select serialized 'serialized_tx
					probe serialized_tx
				]
				break
			]
		]
		serialized_tx
	]

	FindOutputByAddr: func [
		outputs			[block!]
		addr			[string!]
		return:			[integer! block!]
		/local
			i item
	][
		i: 0
		foreach item outputs [
			if item/addresses/1 = addr [
				return reduce [i item/type item/value]
			]
			i: i + 1
		]
		i
	]

	FindInputByTxid: func [
		inputs			[block!]
		txid			[binary!]
		return:			[integer! block!]
		/local
			i item prev-hash
	][
		tx-hash: enbase/base txid 16
		foreach item inputs [
			if item/tx-hash = tx-hash [
				return item
			]
		]
		-1
	]

	SignTx: func [
		outputs_count	[integer!]
		inputs_count	[integer!]
		coin_name		[string!]
		lock_time		[integer!]
		res				[map!]
		return:			[integer! block!]
		/local
			req			[map!]
			len			[integer! block!]
	][
		req: make map! reduce ['outputs_count outputs_count 'inputs_count inputs_count 'coin_name coin_name 'lock_time lock_time]
		len: PinMatrixSequence 'SignTx 'TxRequest req res
		len
	]

	GetPublicKey: func [
		ids				[block!]
		name			[string!]
		res				[map!]
		return:			[integer! block!]
		/local
			req			[map!]
			len			[integer! block!]
	][
		req: make map! reduce ['address_n ids]
		put req 'coin_name name
		len: PinMatrixSequence 'GetPublicKey 'PublicKey req res
		len
	]

	GetAddress: func [
		ids				[block!]
		name			[string!]
		segwit?			[logic!]
		res				[map!]
		return:			[integer! block!]
		/local
			req			[map!]
			len			[integer! block!]
	][
		req: make map! reduce ['address_n ids]
		put req 'coin_name name
		put req 'show_display false
		if segwit? [
			put req 'script_type 'SPENDP2SHWITNESS
		]
		len: PinMatrixSequence 'GetAddress 'Address req res
		len
	]

	;-- A Sequence like this, GetAbcd -> [PinMatrixRequest -> PinMatrixAck -> GetAbcd] -> Abcd
	PinMatrixSequence: func [
		req-msg			[word!]
		res-msg			[word!]
		req				[map!]
		res				[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
	][
		len: encode-and-write req-msg req
		if block? len [return reduce [req-msg 'SendFailed len]]

		clear command-buffer
		len: message-read command-buffer
		if block? len [return reduce [req-msg 'ReadFailed len]]

		if msg-id = trezor-message/get-id 'PinMatrixRequest [
			request-pin-state: 'Requesting
			clear pin-get
			pin-req: req
			pin-msg: req-msg

			view/flags pin-dlg 'modal
		]

		if msg-id = trezor-message/get-id res-msg [
			len: proto-encode/decode trezor-message/messages res-msg res command-buffer
			if block? len [return reduce [res-msg 'DecodeFailed len]]
			return len
		]

		reduce [req-msg 'UnkownId msg-id]
	]

	WriteAndRead: func [
		req-msg			[word!]
		res-msg			[word!]
		req				[map!]
		res				[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
	][
		len: encode-and-write req-msg req
		if block? len [return reduce [req-msg 'SendFailed len]]

		clear command-buffer
		len: message-read command-buffer
		if block? len [return reduce [req-msg 'ReadFailed len]]

		if msg-id = trezor-message/get-id res-msg [
			len: proto-encode/decode trezor-message/messages res-msg res command-buffer
			if block? len [return reduce [res-msg 'DecodeFailed len]]
			return len
		]

		reduce [req-msg 'UnkownId msg-id]
	]

	encode-and-write: func [
		msg				[word!]
		value			[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
	][
		clear command-buffer
		;-- print ["msg: " msg]
		;-- print ["value: " value]
		len: proto-encode/encode trezor-message/messages msg value command-buffer
		if block? len [return reduce ['EncodeFailed len]]
		len: message-write command-buffer trezor-message/get-id msg
		if block? len [return reduce ['WriteFailed len]]
		len
	]

	read-and-decode: func [
		msg				[word!]
		value			[map!]
		return:			[integer! block!]
		/local
			len			[integer! block!]
	][
		clear command-buffer
		len: message-read command-buffer
		if block? len [return reduce ['ReadFailed len]]
		len: proto-encode/decode trezor-message/messages msg value command-buffer
		if block? len [return reduce ['DecodeFailed len]]
		len
	]

	pin-dlg: layout [
		title "Please enter your PIN"
		style label: text 220 middle
		style but: button 60x60 "*"
		style pin-field: field 205 middle
		pad 15x0 header: label "Look at the device for number positions."
		return pad 15x0
		but [append pin-show/text "*" append pin-get "7"]
		but [append pin-show/text "*" append pin-get "8"]
		but [append pin-show/text "*" append pin-get "9"]
		return pad 15x0
		but [append pin-show/text "*" append pin-get "4"]
		but [append pin-show/text "*" append pin-get "5"]
		but [append pin-show/text "*" append pin-get "6"]
		return pad 15x0
		but [append pin-show/text "*" append pin-get "1"]
		but [append pin-show/text "*" append pin-get "2"]
		but [append pin-show/text "*" append pin-get "3"]
		return pad 15x0
		pin-show: pin-field ""
		return pad 15x0
		button "Enter" 205x30 middle [
			if request-pin-state = 'Requesting [
				pin-ret: encode-and-write 'PinMatrixAck make map! reduce ['pin pin-get]
				if block? pin-ret [
					request-pin-state: 'TrezorError
					unview
					exit
				]
				clear command-buffer
				pin-ret: message-read command-buffer
				if block? pin-ret [
					request-pin-state: 'TrezorError
					unview
					exit
				]
				if msg-id = trezor-message/get-id 'Failure [
					clear pin-show/text
					header/text: "Input Pin Failure! Enter Pin again."
					request-pin-cmd
					clear pin-get
					exit
				]
				request-pin-state: 'HasRequested
			]
			unview
		]
		do [
			clear pin-show/text
		]
	]

	;-- high level interface for message write
	message-write: func [
		data			[binary!]
		_id				[integer!]
		return:			[integer! block!]
		/local
			sz			[integer!]
			msg			[binary!]
			ret			[integer! block!]
	][
		clear error
		msg-id: _id
		sz: length? data
		msg: make binary! 8 + sz
		append msg reduce [
			to integer! #"#"
			to integer! #"#"
			to-bin16 _id
			to-bin32 sz
			data
		]
		ret: write msg
		if block? ret [append/only error ['message-write 'Failure] return error]
		ret
	]

	;-- high level interface for message read
	message-read: func [
		data		[binary!]
		return: 	[integer! block!]
		/local
			buf		[binary!]
			size	[integer!]
			max		[integer!]
			ret		[integer! block!]
	][
		clear error
		clear data-frame

		buf: #{000000000000}
		clear buf
		ret: read-buffered buf 1
		if block? ret [append/only error ['message-read 'Failure] return error]
		while [buf/1 <> to integer! #"#"] [
			clear buf
			ret: read-buffered buf 1
			if block? ret [append/only error ['message-read 'Failure] return error]
		]

		clear buf
		ret: read-buffered buf 1
		if block? ret [append/only error ['message-read 'Failure] return error]
		if buf/1 <> to integer! #"#" [append/only error reduce ['message-read 'MagicError buf/1] return error]

		clear buf
		ret: read-buffered buf 6
		if block? ret [append/only error ['message-read 'Failure] return error]
		msg-id: to-int16 buf
		size: to-int32 skip buf 2

		max: 1024 * 1024
		if size > max [append/only error reduce ['message-read 'SizeError size] return error]
		ret: read-buffered data size
		if block? ret [append/only error ['message-read 'Failure] return error]
		ret
	]

	;-- low level read, read data from buffer
	read-buffered: func [
		data		[binary!]
		len			[integer!]
		return:		[integer! block!]
		/local
			n		[integer!]
			ret		[integer! block!]
			sz		[integer!]
	][
		sz: len
		forever [
			if 0 = length? data-frame [
				ret: buffer-report
				if block? ret [append/only error ['read-buffered 'Failure] return error]
			]

			n: read-report-from-buffer data len
			either n < len [
				len: len - n
			][break]
		]
		sz
	]

	read-report-from-buffer: func [
		data		[binary!]
		len			[integer!]
		return:		[integer!]
		/local
			n		[integer!]
	][
		n: length? data-frame
		if len > n [len: n]
		append data copy/part data-frame len
		data-frame: skip data-frame len
		len
	]

	;-- low level read, put report data to buffer
	buffer-report: func [
		return:		[integer! block!]
		/local
			ret		[integer!]
			sz		[integer!]
	][
		until [
			data-frame: clear head data-frame
			ret: hid/read dongle data-frame 50
			ret <> 0
		]
		if ret < 0 [append/only error ['buffer-report 'Failure] return error]
		if ret = 0 [return ret]
		sz: data-frame/1
		if ret - 1 < sz [sz: ret - 1]
		clear skip data-frame sz + 1
		data-frame: skip head data-frame 1
		sz
	]

	;-- low level write: adapt data length
	write: func [
		data			[binary!]
		return:			[integer! block!]
		/local
			len			[integer!]
			sz			[integer!]
			ret			[integer! block!]
			src			[binary!]
	][
		len: length? data
		until [
			sz: length? data
			if sz > 63 [sz: 63]
			ret: write-report data sz
			if block? ret [append/only error ['write 'Failure] return error]
			data: skip data sz
			tail? data
		]
		len
	]

	;-- low level write: only be used by `write`
	write-report: func [
		data			[binary!]
		size			[integer!]
		return:			[integer! block!]
		/local
			i			[integer!]
			cnt			[integer!]
			ret			[integer!]
	][
		clear data-frame
		switch hid-version [
			1	[append data-frame #{3F}]
			2	[append data-frame #{00} append data-frame #{3F}]
		]

		cnt: 1
		loop 63 [
			either cnt <= size [
				append data-frame data/:cnt
			][
				append data-frame #{00}
			]
			cnt: cnt + 1
		]

		ret: hid/write dongle data-frame
		if ret < 0 [append/only error ['write-report 'Failure] return error]
		if ret < length? data-frame [append/only error ['write-report 'SizeError] return error]
		size
	]


	get-hid-version: func [/local data sz][
		clear data-frame
		loop 65 [
			append data-frame #{ff}
		]
		data-frame/1: 0
		data-frame/2: 3Fh
		sz: hid/write dongle data-frame
		if sz = 65 [return 2]

		clear back tail data-frame
		data-frame/1: 3Fh
		data-frame/2: FFh
		sz: hid/write dongle data-frame
		if sz = 64 [return 1]

		0
	]

	close: does [
		if dongle <> none [
			hid/close dongle 
			dongle: none
		]
	]
]

