Red [
	Title:	"bitcoin utility functions"
	Author: "bitbegin"
	File: 	%bitcoin.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]


btc: context [

	get-url: func [network [url!] params [string!] /local net-str res][
		net-str: append copy network params
		res: json/decode read net-str
		res
	]

	get-balance: func [network [url!] address [string!] return: [none! vector! string!]
		/local resp err-no err-msg data balance
	][
		resp: get-url network append copy "/address/" address
		err-no: select resp 'err_no
		if err-no = none [
			wait 0.5
			resp: get-url network append copy "/address/" address
			err-no: select resp 'err_no
		]
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["get-balance error! id: " form err-no " msg: " err-msg]
		]

		data: select resp 'data
		if data = none [return none]
		balance: select data 'balance
		if balance = none [return none]
		to-i256 balance
	]

	;- return: [tx-hash value]
	get-utxs: func [network [url!] address [string!] return: [none! block! string!]
		/local resp err-no err-msg data list utxs item hash value
	][
		resp: get-url network append copy "/address/" reduce [address "/unspent"]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["get-utxs error! id: " form err-no " msg: " err-msg]
		]
		data: select resp 'data
		if data = none [return none]
		list: select data 'list
		if list = none [return none]
		if list = [] [return none]
		utxs: copy []
		foreach item list [
			hash: select item 'tx_hash
			value: select item 'value
			append/only utxs reduce ['tx-hash hash 'value to-i256 value]
		]
		utxs
	]

	get-tx-info: func [network [url!] txid [string!] return: [none! block! string!]
		/local resp err-no err-msg data ret version lock_time inputs outputs item info
	][
		resp: get-url network append copy "/tx/" reduce [txid "?verbose=3"]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["get-tx error! id: " form err-no " msg: " err-msg]
		]
		data: select resp 'data
		if data = none [return none]
		ret: copy []
		version: select data 'version
		if version = none [return none]
		lock_time: select data 'lock_time
		if lock_time = none [return none]
		append ret reduce ['version version]
		append ret reduce ['lock_time lock_time]

		inputs: select data 'inputs
		if inputs = none [return none]
		if inputs = [] [return none]
		outputs: select data 'outputs
		if outputs = none [return none]
		if outputs = [] [return none]

		info: copy []
		foreach item inputs [
			append/only info reduce [
				'prev-addresses select item 'prev_addresses
				'prev-position select item 'prev_position
				'prev-tx-hash select item 'prev_tx_hash
				'script-hex select item 'script_hex
				'prev-type select item 'prev_type
			]
		]
		append ret reduce ['inputs info]

		info: copy []
		foreach item outputs [
			append/only info reduce [
				'addresses select item 'addresses
				'value select item 'value
				'script-hex select item 'script_hex
				'type select item 'type
			]
		]
		append ret reduce ['outputs info]
		ret
	]

	headers: compose [
		Content-Type: "application/json"
		Accept: "application/json"
	]

	publish-tx: func [network [url!] tx [string!] return: [block! string!]
		/local
			body resp data err-no err-msg
	][
		body: make map! reduce ['rawhex tx]
		data: json/encode body
		resp: json/decode write append copy network "/tools/tx-publish" compose/only [
			POST
			(headers)
			(data)
		]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["publish-tx error! id: " form err-no " msg: " err-msg]
		]
		[]
	]

	decode-tx: func [network [url!] tx [string!] return: [block! string!]
		/local
			body resp data err-no err-msg txid
	][
		body: make map! reduce ['rawhex tx]
		data: json/encode body
		resp: json/decode write append copy network "/tools/tx-decode" compose/only [
			POST
			(headers)
			(data)
		]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["decode-tx error! id: " form err-no " msg: " err-msg]
		]
		data: select resp 'data
		if data = none [return "decode-tx error! no data."]
		txid: select data 'txid
		reduce [txid]
	]

]

