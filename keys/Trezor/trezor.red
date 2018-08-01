Red [
	Title:	"high level Driver for Trezor"
	Author: "bitbegin"
	File: 	%trezor.red
	Needs:	 View
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_trezor_red_][
#do [_trezor_red_: yes]
#include %trezor-message.red
#include %trezor-driver.red
#include %../../libs/proto-encode.red
#include %../../libs/int-encode.red
#include %../../libs/rlp.red


trezor: context [
	name: "Trezor"

	system/catalog/errors/user: make system/catalog/errors/user [trezor: ["trezor [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'trezor [name arg2 arg3]
	]

	ids: does [trezor-driver/ids]

	command-buffer: make binary! 1000

	pin-get: make string! 16
	pin-msg: none
	pin-req: none
	pin-ret: none
	request-pin-state: 'Init							;-- Init/Requesting/HasRequested/DeviceError
	req-unit-name: none
	serialized_tx: make binary! 500

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
		trezor-driver/open _id index
	]

	close: does [trezor-driver/close]

	init: does [
		request-pin-state: 'Init
		trezor-driver/init
		trezor/Initialize #()
	]

	close-pin-requesting: does [
		if request-pin-state = 'Requesting [
			unview/only pin-dlg
		]
		request-pin-state: 'Init
	]

	request-pin: func [unitname [string!] return: [word!]] [
		;if request-pin-state <> 'Init [return request-pin-state]

		req-unit-name: unitname
		pin-req: make map! reduce ['address_n reduce [8000002Ch 8000003Ch 80000000h]]
		put pin-req 'show_display false
		pin-msg: 'EthereumGetAddress
		clear pin-get

		request-pin-state: try [request-pin-cmd]
		if error? request-pin-state [return request-pin-state: 'DeviceError]

		if request-pin-state = 'Requesting [
			view/no-wait/flags pin-dlg 'modal
		]

		request-pin-state
	]

	request-pin-cmd: func [return: [word!]][
		encode-and-write pin-msg pin-req
		trezor-driver/message-read clear command-buffer

		if trezor-driver/msg-id = trezor-message/get-id 'EthereumAddress [ 
			return 'HasRequested
		]
		if trezor-driver/msg-id <> trezor-message/get-id 'PinMatrixRequest [
			return 'DeviceError
		]
		'Requesting
	]

	get-eth-address: func [
		ids				[block!]
		return:			[string!]
		/local
			res len
	][
		res: make map! []
		EthereumGetAddress ids res
		if res/address = none [new-error 'get-eth-address "addr none" res]
		rejoin ["0x" enbase/base res/address 16]
	]

	get-btc-address: func [
		ids				[block!]
		return:			[string!]
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
		GetAddress ids coin-name segwit? res
		if res/address = none [new-error 'get-btc-address "addr none" res]
		res/address
	]

	get-eth-signed-data: func [
		ids				[block!]
		tx				[block!]
		chain-id		[integer!]
		return:			[binary!]
		/local
			req			[map!]
			res			[map!]
			nonce
			gas_price
			gas_limit
			amount
			signed
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
		EthereumSignTx req res

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
		return:			[integer!]
	][
		WriteAndRead 'Initialize 'Features #() res
	]

	EthereumGetAddress: func [
		ids				[block!]
		res				[map!]
		return:			[integer!]
		/local
			req			[map!]
	][
		req: make map! reduce ['address_n ids]
		put req 'show_display false
		PinMatrixSequence 'EthereumGetAddress 'EthereumAddress req res
	]

	EthereumSignTx: func [
		req				[map!]
		res				[map!]
		return:			[integer!]
		/local
			res2		[map!]
	][
		encode-and-write 'EthereumSignTx req
		trezor-driver/message-read clear command-buffer

		if trezor-driver/msg-id = trezor-message/get-id 'PinMatrixRequest [
			request-pin-state: 'Requesting
			clear pin-get
			pin-req: req
			pin-msg: 'EthereumSignTx

			view/flags pin-dlg 'modal
		]

		if trezor-driver/msg-id <> trezor-message/get-id 'ButtonRequest [
			new-error 'EthereumSignTx "not ButtonRequest" trezor-driver/msg-id
		]

		res2: make map! []
		proto-encode/decode trezor-message/messages 'ButtonRequest res2 command-buffer
		res2: make map! []
		WriteAndRead 'ButtonAck 'ButtonRequest #() res2
		WriteAndRead 'ButtonAck 'EthereumTxRequest #() res
	]

	SignTxSequence: func [
		tx				[block!]
		return:			[block! binary!]
		/local
			input-segwit?
			coin_name res-in req sub-req
			request_type details request_index tx_hash serialized
			tx-input tx-output pre-input pre-output script_type addr-name addr
			last-request_type
			last-output-remove
			bin
	][
		clear serialized_tx
		last-request_type: none
		last-output-remove: false

		coin_name: "Bitcoin"
		if tx/inputs/1/path/2 = (80000000h + 1) [
			coin_name: "Testnet"
		]
		input-segwit?: false
		if tx/inputs/1/path/1 = (80000000h + 49) [
			input-segwit?: true
		]
		res-in: make map! []

		;-- first step, send "SignTx" message
		SignTx length? tx/outputs length? tx/inputs coin_name 0 res-in

		forever [
			probe res-in
			request_type: select res-in 'request_type
			if request_type = 'TXINPUT [
				details: select res-in 'details
				serialized: select res-in 'serialized
				request_index: select details 'request_index
				tx_hash: select details 'tx_hash
				if all [tx_hash = none request_index <> none] [
					tx-input: tx/inputs/(request_index + 1)
					pre-output: FindOutputByAddr tx-input/info/outputs tx-input/addr
					script_type: either pre-output/2 = "P2SH" ['SPENDP2SHWITNESS]['SPENDADDRESS]
					sub-req: make map! reduce [
								'address_n tx-input/path
								'prev_hash debase/base tx-input/tx-hash 16
								'prev_index pre-output/1
								'sequence -1
								'script_type script_type]
					if pre-output/2 = "P2SH" [
						put sub-req 'amount trim/head i256-to-bin pre-output/3
					]
					req: make map! []
					put req 'inputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					clear res-in
					WriteAndRead 'TxAck 'TxRequest req res-in
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
					clear res-in
					WriteAndRead 'TxAck 'TxRequest req res-in
				]
				if serialized [
					if all [last-request_type = 'TXOUTPUT last-output-remove] [remove back tail serialized_tx]
					last-output-remove: false
					append serialized_tx select serialized 'serialized_tx
					probe serialized_tx
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
					clear res-in
					WriteAndRead 'TxAck 'TxRequest req res-in
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
								'amount trim/head i256-to-bin pre-output/value
								'script_pubkey debase/base pre-output/script-hex 16]
					req: make map! []
					put req 'bin_outputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					clear res-in
					WriteAndRead 'TxAck 'TxRequest req res-in
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
					if not input-segwit? [
						script_type: 'PAYTOADDRESS
					]
					sub-req: make map! reduce [
								addr-name addr
								'amount trim/head i256-to-bin tx-output/value
								'script_type script_type]
					req: make map! []
					put req 'outputs reduce [sub-req]
					req: make map! reduce ['tx req]
					probe req
					clear res-in
					encode-and-write 'TxAck req
					trezor-driver/message-read clear command-buffer
					either trezor-driver/msg-id = trezor-message/get-id 'TxRequest [
						proto-encode/decode trezor-message/messages 'TxRequest res-in command-buffer
					][
						either trezor-driver/msg-id = trezor-message/get-id 'ButtonRequest [
							clear res-in
							proto-encode/decode trezor-message/messages 'ButtonRequest res-in command-buffer

							encode-and-write 'ButtonAck make map! []

							clear res-in
							read-and-decode 'TxRequest res-in
							if trezor-driver/msg-id = trezor-message/get-id 'ButtonRequest [
								clear res-in
								proto-encode/decode trezor-message/messages 'ButtonRequest res-in command-buffer

								encode-and-write 'ButtonAck make map! []

								clear res-in
								read-and-decode 'TxRequest res-in
							]
						][
							new-error 'SignTxSequence "not support" 'trezor-driver/msg-id
						]
					]
				]
				if serialized [
					bin: select serialized 'serialized_tx
					if all [last-request_type = 'TXOUTPUT last-output-remove] [remove back tail serialized_tx]
					either all [bin/1 = #{02} 33 = length? bin][
						last-output-remove: true
					][
						last-output-remove: false
					]
					append serialized_tx bin
					probe serialized_tx
				]
			]
			if request_type = 'TXFINISHED [
				serialized: select res-in 'serialized
				if serialized [
					;if all [last-request_type = 'TXOUTPUT last-output-remove] [remove back tail serialized_tx]
					;last-output-remove: false
					append serialized_tx select serialized 'serialized_tx
					probe serialized_tx
				]
				break
			]
			last-request_type: request_type
		]
		serialized_tx
	]

	FindOutputByAddr: func [
		outputs			[block!]
		addr			[string!]
		return:			[block!]
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
		new-error 'FindOutputByAddr "not found" reduce [outputs addr]
	]

	FindInputByTxid: func [
		inputs			[block!]
		txid			[binary!]
		return:			[block!]
		/local
			i item prev-hash
	][
		tx-hash: enbase/base txid 16
		foreach item inputs [
			if item/tx-hash = tx-hash [
				return item
			]
		]
		new-error 'FindInputByTxid "not found" reduce [inputs txid]
	]

	;-- base message transfer
	SignTx: func [
		outputs_count	[integer!]
		inputs_count	[integer!]
		coin_name		[string!]
		lock_time		[integer!]
		res				[map!]
		return:			[integer!]
		/local
			req			[map!]
	][
		req: make map! reduce ['outputs_count outputs_count 'inputs_count inputs_count 'coin_name coin_name 'lock_time lock_time]
		PinMatrixSequence 'SignTx 'TxRequest req res
	]

	GetPublicKey: func [
		ids				[block!]
		name			[string!]
		res				[map!]
		return:			[integer!]
		/local
			req			[map!]
	][
		req: make map! reduce ['address_n ids]
		put req 'coin_name name
		PinMatrixSequence 'GetPublicKey 'PublicKey req res
	]

	GetAddress: func [
		ids				[block!]
		name			[string!]
		segwit?			[logic!]
		res				[map!]
		return:			[integer!]
		/local
			req			[map!]
	][
		req: make map! reduce ['address_n ids]
		put req 'coin_name name
		put req 'show_display false
		if segwit? [
			put req 'script_type 'SPENDP2SHWITNESS
		]
		PinMatrixSequence 'GetAddress 'Address req res
	]

	;-- A Sequence like this, GetAbcd -> [PinMatrixRequest -> PinMatrixAck -> GetAbcd] -> Abcd
	PinMatrixSequence: func [
		req-msg			[word!]
		res-msg			[word!]
		req				[map!]
		res				[map!]
		return:			[integer!]
	][
		encode-and-write req-msg req
		trezor-driver/message-read clear command-buffer

		if trezor-driver/msg-id = trezor-message/get-id 'PinMatrixRequest [
			request-pin-state: 'Requesting
			clear pin-get
			pin-req: req
			pin-msg: req-msg

			view/flags pin-dlg 'modal
		]

		if trezor-driver/msg-id = trezor-message/get-id res-msg [
			return proto-encode/decode trezor-message/messages res-msg res command-buffer
		]

		new-error 'PinMatrixSequence "unknown id" trezor-driver/msg-id
	]

	WriteAndRead: func [
		req-msg			[word!]
		res-msg			[word!]
		req				[map!]
		res				[map!]
		return:			[integer!]
	][
		encode-and-write req-msg req
		trezor-driver/message-read clear command-buffer

		if trezor-driver/msg-id = trezor-message/get-id res-msg [
			return proto-encode/decode trezor-message/messages res-msg res command-buffer
		]

		new-error 'WriteAndRead "unknown id" trezor-driver/msg-id
	]

	encode-and-write: func [
		msg				[word!]
		value			[map!]
		return:			[integer!]
	][
		;-- print ["msg: " msg]
		;-- print ["value: " value]
		proto-encode/encode trezor-message/messages msg value clear command-buffer
		trezor-driver/message-write command-buffer trezor-message/get-id msg
	]

	read-and-decode: func [
		msg				[word!]
		value			[map!]
		return:			[integer!]
	][
		trezor-driver/message-read clear command-buffer
		proto-encode/decode trezor-message/messages msg value command-buffer
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
				pin-ret: try [encode-and-write 'PinMatrixAck make map! reduce ['pin pin-get]]
				if error? pin-ret [
					request-pin-state: 'DeviceError
					unview
					exit
				]
				pin-ret: try [trezor-driver/message-read clear command-buffer]
				if error? pin-ret [
					request-pin-state: 'DeviceError
					unview
					exit
				]
				if trezor-driver/msg-id = trezor-message/get-id 'Failure [
					clear pin-show/text
					header/text: "Input Pin Failure! Enter Pin again."
					request-pin-state: try [request-pin-cmd]
					if error? request-pin-state [
						request-pin-state: 'DeviceError
						unview
					]
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

]

]
