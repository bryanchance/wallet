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
#include %int-encode.red

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

	call-rpc: func [network [url!] method [word!] params [none! block!] /local data blk res][
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
			new-error 'call-rpc "server error" reduce [network res]
		]
		data
	]

	get-url: func [url [url!] return: [map!]
		/local res 
	][
		if all [not error? res: try [read url] map? res: json/decode res][return res]

		wait 0.5
		if map? res: json/decode read url [return res]
		new-error 'get-url "server error" url
	]

	parse-balance: function [amount][
		either (length? amount) % 2 <> 0 [
			poke amount 2 #"0"
			n: 1
		][n: 2]
		to-i256 debase/base skip amount n 16
	]

	rpc-net: context [
		get-token-balance: func [network [url!] contract [string!] address [string!] return: [vector!] /local token-url params res][
			token-url: rejoin ["0x" contract]
			params: make map! 4
			params/to: token-url
			params/data: rejoin ["0x70a08231" pad64 copy skip address 2]
			res: call-rpc network 'eth_call reduce [params 'latest]
			parse-balance res
		]

		get-eth-balance: func [network [url!] address [string!] return: [vector!] /local res][
			res: call-rpc network 'eth_getBalance reduce [address 'latest]
			parse-balance res
		]

		get-balance: func [network [url!] contract [string! none!] address [string!] return: [vector!]][
			either contract [get-token-balance network contract address][
				get-eth-balance network address
			]
		]

		get-nonce: func [network [url!] address [string!] return: [integer!] /local n res][
			res: call-rpc network 'eth_getTransactionCount reduce [address 'pending]

			either (length? res) % 2 <> 0 [
				poke res 2 #"0"
				n: 1
			][n: 2]
			to integer! debase/base skip res n 16
		]

		publish-tx: func [network [url!] data [binary!] return: [string!]][
			call-rpc network 'eth_sendRawTransaction reduce [
				rejoin ["0x" enbase/base data 16]
			]
		]
	]

	get-balance: func [nettype [word!] network [url!] contract [string! none!] address [string!] return: [vector!]][
		case [
			nettype = 'rpc [rpc-net/get-balance network contract copy address]
			true [new-error 'get-balance "type error" nettype]
		]
	]

	get-nonce: func [nettype [word!] network [url!] address [string!] return: [integer!]][
		case [
			nettype = 'rpc [rpc-net/get-nonce network copy address]
			true [new-error 'get-nonce "type error" nettype]
		]
	]

	publish-tx: func [nettype [word!] network [url!] data [binary!]][
		case [
			nettype = 'rpc [rpc-net/publish-tx network data]
			true [new-error 'publish-tx "type error" nettype]
		]
	]

	get-gas-price: func [speed [word!] return: [vector! none!] /local network res][
		if all [speed <> 'standard speed <> 'fastest speed <> 'safeLow speed <> 'fast][return none]
		network: https://www.etherchain.org/api/gasPriceOracle
		either all [map? res: try [get-url network] res: select res speed][
			string-to-i256 res 9
		][none]
	]
]

]
