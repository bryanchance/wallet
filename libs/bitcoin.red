Red [
	Title:	"bitcoin utility functions"
	Author: "bitbegin"
	File: 	%bitcoin.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]


btc: context [

	get-url: func [network [url!] params [string!] /local res][
		res: json/decode read append copy network params
		res
	]

	get-balance: func [network [url!] address [string!] return: [none! vector! string!]
		/local resp err-no err-msg data balance
	][
		resp: get-url network append copy "/address/" address
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["get-address error! id: " form err-no " msg: " err-msg]
		]
		data: select resp 'data
		if data = none [return none]
		balance: select data 'balance
		if balance = none [return none]
		to-i256 balance
	]

	get-utxs: func [network [url!] address [string!] return: [none! block! string!]
		/local resp err-no err-msg data list utxs item hash value
	][
		resp: get-url network append copy "/address/" reduce [address "/unspent"]
		err-no: select resp 'err_no
		if 0 <> err-no [
			err-msg: select resp 'err_msg
			return rejoin ["get-utx error! id: " form err-no " msg: " err-msg]
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
			append utxs reduce [hash to-i256 value]
		]
		utxs
	]

]

