Red [
	Title:	"network api for eth"
	Author: "Xie Qingtian & bitbegin"
	File: 	%eth-api.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_eth-api_red_][
#do [_eth-api_red_: yes]
#include %JSON.red
#include %int256.red

eth-api: context [

	system/catalog/errors/user: make system/catalog/errors/user [eth-api: ["eth-api [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'eth-api [name arg2 arg3]
	]

	half-scalar: to-i256 1e9
	top-scalar: mul256 half-scalar half-scalar
	gwei-to-wei: func [num [vector!] return: [vector!]][
		mul256 num half-scalar
	]
	eth-to-gwei: func [num [vector!] return: [vector!]][
		mul256 num half-scalar
	]
	eth-to-wei: func [num [vector!] return: [vector!]][
		mul256 num top-scalar
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
		blk: compose/only [
			POST
			(headers)
			(to-binary data)
		]
		res: json/decode write network blk
		unless data: select res 'result [			;-- error
			err-msg: select res 'error
			new-error 'call-rpc "server error" reduce [network err-msg]
		]
		data
	]

	parse-balance: function [amount][
		either (length? amount) % 2 <> 0 [
			poke amount 2 #"0"
			n: 1
		][n: 2]
		to-i256 debase/base skip amount n 16
	]

	get-token-balance: func [network [url!] contract [string!] address [string!] /local token-url params res][
		token-url: rejoin ["0x" contract]
		params: make map! 4
		params/to: token-url
		params/data: rejoin ["0x70a08231" pad64 copy skip address 2]
		res: call-rpc network 'eth_call reduce [params 'latest]
		parse-balance res
	]

	get-eth-balance: func [network [url!] address [string!] /local res][
		res: call-rpc network 'eth_getBalance reduce [address 'latest]
		parse-balance res
	]

	get-balance: func [network [url!] contract [string! none!] address [string!]][
		either contract [get-token-balance network contract address][
			get-eth-balance network address
		]
	]

	get-nonce: func [network [url!] address [string!] /local n res][
		res: call-rpc network 'eth_getTransactionCount reduce [address 'pending]

		either (length? res) % 2 <> 0 [
			poke res 2 #"0"
			n: 1
		][n: 2]
		to integer! debase/base skip res n 16
	]

	get-url: func [url [url!] return: [map!]
		/local res 
	][
		if all [not error? res: try [read url] map? res: json/decode res][return res]

		wait 0.5
		if map? res: json/decode read url [return res]
		new-error 'get-url "server error" url
	]

	get-gas-price: func [speed [word!] return: [vector! none!] /local network res][
		if all [speed <> 'average speed <> 'fastest speed <> 'safeLow speed <> 'fast][return none]
		network: https://ethgasstation.info/json/ethgasAPI.json
		either all [map? res: try [get-url network] res: select res speed][
			res: to float! res / 10.0
			gwei-to-wei to-i256 res
		][none]
	]
]

]
