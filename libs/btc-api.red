Red [
	Title:	"network api for btc"
	Author: "bitbegin"
	File: 	%btc-api.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]


btc-api: context [

	timeout-error: func [name][
		chain-error/new name none 'network-timeout none
	]

	get-url: func [network [url!] params [string!] return: [map!]
		/local net-str resp res
	][
		net-str: append copy network params
		resp: attempt [read net-str]
		unless resp [
			wait 0.5
			resp: attempt [read net-str]
			unless resp [return chain-error/new 'get-url network net-str timeout-error 'get-url]
		]
		res: json/decode resp
		res
	]

	get-balance: func [network [url!] address [string!] return: [none! vector! map!]
		/local resp err-no err-msg data balance
	][
		resp: get-url network append copy "/address/" address
		if chain-error/error? resp [return chain-error/new 'get-balance network address resp]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return chain-error/new 'get-balance err-no err-msg none
		]

		unless data: select resp 'data [return none]
		unless balance: select data 'balance [return none]
		to-i256 balance
	]

	;- return: [tx-hash value]
	get-unspent: func [network [url!] address [string!] return: [none! block! map!]
		/local resp err-no err-msg data list utxs item hash value
	][
		resp: get-url network append copy "/address/" reduce [address "/unspent"]
		if chain-error/error? resp [return chain-error/new 'get-unspent network address resp]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return chain-error/new 'get-unspent err-no err-msg none
		]
		unless data: select resp 'data [return none]
		unless list: select data 'list [return none]
		if list = [] [return none]
		utxs: copy []
		foreach item list [
			hash: select item 'tx_hash
			value: select item 'value
			append/only utxs reduce ['tx-hash hash 'value to-i256 value]
		]
		utxs
	]

	get-tx-info: func [network [url!] txid [string!] return: [none! block! map!]
		/local resp err-no err-msg data ret version lock_time inputs outputs item info
	][
		resp: get-url network append copy "/tx/" reduce [txid "?verbose=3"]
		if chain-error/error? resp [return chain-error/new 'get-tx-info network address resp]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return chain-error/new 'get-tx-info err-no err-msg none
		]
		unless data: select resp 'data [return none]
		ret: copy []
		unless version: select data 'version [return none]
		unless lock_time: select data 'lock_time [return none]
		append ret reduce ['version version]
		append ret reduce ['lock_time lock_time]

		unless inputs: select data 'inputs [return none]
		if inputs = [] [return none]
		unless outputs: select data 'outputs [return none]
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

	publish-tx: func [network [url!] tx [string!] return: [block! map!]
		/local
			body resp data err-no err-msg
	][
		body: make map! reduce ['rawhex tx]
		data: json/encode body
		resp: attempt [
			write append copy network "/tools/tx-publish" compose/only [
				POST
				(headers)
				(data)
			]
		]
		unless resp [return chain-error/new 'publish-tx network tx timeout-error 'publish-tx]
		resp: json/decode resp
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return chain-error/new 'publish-tx err-no err-msg none
		]
		[]
	]

	decode-tx: func [network [url!] tx [string!] return: [block! string!]
		/local
			body resp data err-no err-msg txid
	][
		body: make map! reduce ['rawhex tx]
		data: json/encode body
		resp: attempt [
			write append copy network "/tools/tx-decode" compose/only [
				POST
				(headers)
				(data)
			]
		]
		unless resp [return chain-error/new 'decode-tx network tx timeout-error 'publish-tx]
		resp: json/decode resp
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return chain-error/new 'decode-tx err-no err-msg none
		]
		unless data: select resp 'data [return chain-error/new 'decode-tx none "no data" none]
		unless txid: select data 'txid [return chain-error/new 'decode-tx none "no txid" none]
		reduce [txid]
	]

]

