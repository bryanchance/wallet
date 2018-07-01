Red [
	Title:	"network api for eth"
	Author: "Xie Qingtian & bitbegin"
	File: 	%eth-api.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

eth-api: context [

	timeout-error: func [name][
		chain-error/new name none 'network-timeout none
	]

	pad64: function [data [string! binary!]][
		n: length? data
		either binary? data [c: #{00} len: 32][c: #"0" len: 64]
		if n < len [
			insert/dup data c len - n
		]
		data
	]

	headers: compose [
		Content-Type: "application/json"
		Accept: "application/json"
		Cookie: (make string! 16)
		User-Agent: (
			form reduce [
				"Red Wallet version"
				"0.1.0" ;#do keep [read %version.red]
				"for" system/platform
			]
		)
	]

	body: #(
		jsonrpc: "2.0"
		id: 1
		method: none
		params: none
	)

	cookie: func [str [string!]][
		lowercase take/part enbase/base checksum str 'sha256 16 16
	]

	call-rpc: func [network [url!] method [word!] params [none! block!] /local data blk res err-msg error][
		body/method: method
		body/params: params
		data: json/encode body
		headers/cookie: cookie data
		blk: [
			compose/only [
				POST
				(headers)
				(to-binary data)
			]
		]
		res: attempt [write network blk]
		unless res [
			wait 0.3
			res: attempt [write network blk]
			unless res [return chain-error/new 'call-rpc network blk timeout-error 'call-rpc]
		]
		res: json/decode res
		unless data: select res 'result [			;-- error
			err-msg: select res 'error
			error: chain-error/new 'call-rpc network err-msg none
			return chain-error/new 'call-rpc network blk error
		]
		data
	]

	parse-balance: function [amount][
		either (length? amount) % 2 <> 0 [
			poke amount 2 #"0"
			n: 1
		][n: 2]
		n: to-i256 debase/base skip amount n 16
		n: i256-to-float n
		n / 1e18
	]

	get-balance-token: func [network [url!] contract [string!] address [string!] /local token-url params res][
		token-url: rejoin ["0x" contract]
		params: make map! 4
		params/to: token-url
		params/data: rejoin ["0x70a08231" pad64 copy skip address 2]
		res: call-rpc network 'eth_call reduce [params 'latest]
		if chain-error/error? res [return chain-error/new 'get-balance-token network reduce [address contract] res]
		parse-balance res
	]

	get-balance: func [network [url!] address [string!] /local res][
		res: call-rpc network 'eth_getBalance reduce [address 'latest]
		if chain-error/error? res [return chain-error/new 'get-balance network address res]
		parse-balance res
	]

	get-nonce: func [network [url!] address [string!] /local n res][
		res: call-rpc network 'eth_getTransactionCount reduce [address 'pending]
		if chain-error/error? res [return chain-error/new 'get-nonce network address res]

		either (length? res) % 2 <> 0 [
			poke res 2 #"0"
			n: 1
		][n: 2]
		to integer! debase/base skip res n 16
	]
]