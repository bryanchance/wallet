Red [
	Title:	"network api for btc"
	Author: "bitbegin"
	File: 	%btc-api.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#do [_btc-api_red_: yes]
#if error? try [_json_red_] [#include %JSON.red]
#if error? try [_int256_red_] [#include %int256.red]

btc-api: context [

	system/catalog/errors/user: make system/catalog/errors/user [btc-api: ["btc-api [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'btc-api [name arg2 arg3]
	]

	get-url: func [url [url!] return: [map!]
		/local res 
	][
		res: try [read url]
		if not error? res [
			res: json/decode res
			if res <> [] [return res]
		]

		wait 0.5
		res: try [read url]
		if error? res [new-error 'get-url "timeout" url]

		res: json/decode res
		if res = [] [new-error 'get-url "server error" url]
		res
	]

	get-balance: func [network [url!] address [string!] return: [none! vector!]
		/local url resp err-no err-msg data balance
	][
		url: rejoin [network "/address/" address]
		resp: get-url url
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			new-error 'get-balance "server error" reduce [url err-no err-msg]
		]

		unless data: select resp 'data [return none]
		unless balance: select data 'balance [return none]
		to-i256 balance
	]

	get-unspent: func [network [url!] address [string!] return: [none! block!]
		/local url resp err-no err-msg data list utxs item
	][
		url: rejoin [network "/address/" address "/unspent"]
		resp: get-url url
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			new-error 'get-unspent "server error" reduce [url err-no err-msg]
		]
		unless data: select resp 'data [return none]
		unless list: select data 'list [return none]
		if list = [] [return none]
		utxs: copy []
		foreach item list [
			hash: select item 'tx_hash
			value: select item 'value
			append/only utxs reduce [
				'tx-hash select item 'tx_hash
				'value to-i256 select item 'value
			]
		]
		utxs
	]

	get-tx-info: func [network [url!] txid [string!] return: [none! block!]
		/local url resp err-no err-msg data ret version lock_time inputs outputs item info
	][
		url: rejoin [network "/tx/" txid "?verbose=3"]
		resp: get-url url
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			new-error 'get-tx-info "server error" reduce [url err-no err-msg]
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
				'value to-i256 select item 'value
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

	post-url: func [url [url!] body [map!] return: [map!]
		/local command res 
	][
		command: compose/only [
				POST
				(headers)
				(json/encode body)
		]
		res: try [write url command]
		if not error? res [
			res: json/decode res
			if res <> [] [return res]
		]

		wait 0.5
		res: try [write url command]
		if error? res [new-error 'post-url "timeout" reduce [url command]]

		res: json/decode res
		if res = [] [new-error 'post-url "server error" [url command]]
		res
	]

	publish-tx: func [network [url!] tx [string!] return: [logic!]
		/local
			url body resp err-no err-msg
	][
		url: rejoin [network "/tools/tx-publish"]
		body: make map! reduce ['rawhex tx]
		resp: post-url url body
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			new-error 'publish-tx "server error" reduce [url err-no err-msg]
		]
		true
	]

	decode-tx: func [network [url!] tx [string!] return: [string!]
		/local
			url body resp data err-no err-msg txid
	][
		url: rejoin [network "/tools/tx-decode"]
		body: make map! reduce ['rawhex tx]
		resp: post-url url body
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			new-error 'decode-tx "server error" reduce [url err-no err-msg]
		]
		unless data: select resp 'data [new-error 'decode-tx "no data" url]
		unless txid: select data 'txid [new-error 'decode-tx "no txid" url]
		txid
	]

]

