Red [
	Title:	 "RED Wallet"
	Author:  "Xie Qingtian"
	File: 	 %wallet.red
	Icon:	 %assets/RED-token.ico
	Needs:	 View
	Version: 0.1.0
	Tabs: 	 4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %libs/int256.red
#include %libs/JSON.red
#include %libs/rlp.red
#include %libs/proto-encode.red
#include %libs/ethereum.red
#include %libs/bitcoin.red
#include %libs/HID/hidapi.red
#include %keys/keys.red

#include %eth-ui.red
#include %btc-ui.red

#system [
	with gui [#include %libs/usb-monitor.reds]
]

wallet: context [

	list-font: make font! [name: get 'font-fixed size: 11]

	signed-data: addr-list: min-size: none
	addr-per-page: 5

	;-- m / purpose' / coin_type' / account' / change / address_index
	default-purpose: 80000000h + 44
	segwit-purpose: 80000000h + 49
	btc-coin: 80000000h + 0
	btc-test-coin: 80000000h + 1
	eth-coin: 80000000h + 60
	default-account: 80000000h + 0
	default-change: 0

	coins: compose/deep [
		;token name
		"ETH" [
			;coin name		;net name		;net server										;explorer server									;BIP32 path																		;chain id			;contract address
			"ETH"			"mainnet"		https://eth.red-lang.org/mainnet				https://etherscan.io/tx/							[(default-purpose) (eth-coin) (default-account) (default-change)]				1					#[none]
			"ETH"			"Rinkeby"		https://eth.red-lang.org/rinkeby				https://rinkeby.etherscan.io/tx/					[(default-purpose) (eth-coin) (default-account) (default-change)]				4					#[none]
			"ETH"			"Kovan"			https://eth.red-lang.org/kovan					https://kovan.etherscan.io/tx/						[(default-purpose) (eth-coin) (default-account) (default-change)]				42					#[none]
			"ETH"			"Ropsten"		https://eth.red-lang.org/ropsten				https://ropsten.etherscan.io/tx/					[(default-purpose) (eth-coin) (default-account) (default-change)]				3					#[none]
		]
		"RED" [
			"RED"			"mainnet"		https://eth.red-lang.org/mainnet				https://etherscan.io/tx/							[(default-purpose) (eth-coin) (default-account) (default-change)]				1					"76960Dccd5a1fe799F7c29bE9F19ceB4627aEb2f"
			"RED"			"Rinkeby"		https://eth.red-lang.org/rinkeby				https://rinkeby.etherscan.io/tx/					[(default-purpose) (eth-coin) (default-account) (default-change)]				4					"43df37f66b8b9fececcc3031c9c1d2511db17c42"
		]
		"BTC" [
			"BTC"			"BTC.COM"		https://chain.api.btc.com/v3					https://blockchain.info/tx/							[(segwit-purpose) (btc-coin) (default-account) (default-change)]				#[none]				#[none]
			"TEST"			"testnet"		https://tchain.api.btc.com/v3					https://testnet.blockchain.info/tx/					[(segwit-purpose) (btc-test-coin) (default-account) (default-change)]			#[none]				#[none]
		]
		"BTC-old" [
			"BTC"			"BTC.COM"		https://chain.api.btc.com/v3					https://blockchain.info/tx/							[(default-purpose) (btc-coin) (default-account) (default-change)]				#[none]				#[none]
			"TEST"			"testnet"		https://tchain.api.btc.com/v3					https://testnet.blockchain.info/tx/					[(default-purpose) (btc-test-coin) (default-account) (default-change)]			#[none]				#[none]
		]
	]

	tokens: extract coins 2

	;-- current token name
	token-name: tokens/1			;-- default "ETH"
	
	net-names: extract/index coins/:token-name 7 2
	networks: extract/index coins/:token-name 7 3
	explorers: extract/index coins/:token-name 7 4

	;-- current net name
	net-name: net-names/2			;-- default "Rinkeby"

	GetCoinItem: func [NetName index /local info len i item][
		info: coins/:token-name
		len: (length? info) / 7
		repeat i len [
			item: i - 1 * 7
			if info/(item + 2) = NetName [return info/(item + index)]
		]
		none
	]
	get-coin-name: does [GetCoinItem net-name 1]
	get-network: does [GetCoinItem net-name 3]
	get-explorer: does [GetCoinItem net-name 4]
	get-bip32-path: does [GetCoinItem net-name 5]
	get-chain-id: does [GetCoinItem net-name 6]
	get-contract-addr: does [GetCoinItem net-name 7]

	coin-name: get-coin-name
	network: get-network
	explorer: get-explorer
	token-contract: get-contract-addr
	bip32-path: get-bip32-path

	connected?:		no
	address-index:	0
	page:			0

	process-events: does [loop 10 [do-events/no-wait]]
	
	form-amount: func [value [float!]][
		pos: find value: form value #"."
		head insert/dup value #" " 8 - ((index? pos) - 1)
	]

	enumerate-connected-devices: func [/local len] [
		key/enumerate-connected-devices
		dev-list/data: key/get-valid-names
		len: length? dev-list/data
		if len < dev-list/selected [dev-list/selected: len]
		if all [len = 1 dev-list/data/1 = key/no-dev] [
			info-msg/text: "Please plug in your key..."
			dev-list/selected: 1
			clear addr-list/data
		]
	]

	free-enumerate-connected-devices: does [
		key/free-enum
	]

	get-device-name: func [
		return:			[string!]
		/local
			index
			names
			blk
	][
		index: dev-list/selected
		names: dev-list/data
		if names = none [return key/no-dev]
		blk: split names/:index ": "
		blk/1
	]

	get-device-index: func [
		return:			[integer!]
		/local
			index
			names
			blk
	][
		index: dev-list/selected
		names: dev-list/data
		if names = none [return 0]		
		blk: split names/:index ": "
		if blk/2 = none [return 0]
		blk/2
	]

	connect-device: func [
		/local name index
	][
		update-ui no

		name: get-device-name
		index: get-device-index

		if name = key/no-dev [
			exit
		]

		either none <> key/connect name index [
			process-events
			usb-device/rate: none

			if 'InitSuccess <> key/set-init name [
				info-msg/text: "Initialize the key failed..."
				exit
			]

			if 'Init = key/get-request-pin-state-by-name name [
				if 'HasRequested <> key/request-pin-by-name name [
					usb-device/rate: 0:0:1
					info-msg/text: "Please unlock your key"
				]
				;-- print 'Init
			]
			connected?: yes			
		][
			info-msg/text: "This device can't be recognized"
		]
	]

	list-addresses: func [
		/prev /next 
		/local
			name
			addresses addr n
			res
			req-pin-state
	][
		update-ui no

		if connected? [
			name: get-device-name
			;-- print name
			req-pin-state: key/get-request-pin-state-by-name name
			;-- print req-pin-state
			if req-pin-state <> 'HasRequested [
				exit
			]
			info-msg/text: "Please wait while loading addresses..."

			addresses: clear []
			clear btc-ui/addr-balances
			if next [page: page + 1]
			if prev [page: page - 1]
			n: page * addr-per-page
			
			loop addr-per-page [
				either any [token-name = "ETH" token-name = "RED"][
					if not eth-ui/show-address name n addresses [exit]
					process-events
					n: n + 1
				][
					if not btc-ui/show-address name n addresses [exit]
					process-events
					n: n + 1
				]
			]
			if any [token-name = "ETH" token-name = "RED"][
				eth-ui/enum-address-balance
			]
			update-ui yes
			do-auto-size addr-list
		]
	]

	do-select-dev: func [face [object!] event [event!]][
		connected?: no
		key/close
		enumerate-connected-devices
		connect-device
		list-addresses
		free-enumerate-connected-devices
	]

	do-select-network: func [face [object!] event [event!] /local idx][
		idx: face/selected
		net-name: face/data/:idx

		coin-name: get-coin-name
		network: get-network
		explorer: get-explorer
		token-contract: get-contract-addr
		bip32-path: get-bip32-path

		do-reload
	]

	do-select-token: func [face [object!] event [event!] /local idx net][
		idx: face/selected
		net: net-list/selected
		token-name: face/data/:idx

		net-names: extract/index coins/:token-name 7 2
		networks: extract/index coins/:token-name 7 3
		explorers: extract/index coins/:token-name 7 4

		net-list/data: net-names
		net: net-list/selected: either net > length? net-list/data [1][net]
		net-name: net-list/data/:net

		coin-name: get-coin-name
		network: get-network
		explorer: get-explorer
		token-contract: get-contract-addr
		bip32-path: get-bip32-path

		do-reload
	]
	
	do-reload: does [if connected? [list-addresses]]
	
	do-resize: function [delta [pair!]][
		ref: as-pair btn-send/offset/x - 10 ui/extra/y / 2
		foreach-face ui [
			pos: face/offset
			case [
				all [pos/x > ref/x pos/y < ref/y][face/offset/x: pos/x + delta/x]
				all [pos/x < ref/x pos/y > ref/y][face/offset/y: pos/y + delta/y]
				all [pos/x > ref/x pos/y > ref/y][face/offset: pos + delta]
			]
		]
		addr-list/size: addr-list/size + delta
	]
	
	do-auto-size: function [face [object!]][
		size: size-text/with face "X"
		cols: 64
		if face/data [foreach line face/data [cols: max cols length? line]]
		delta: (as-pair size/x * cols size/y * 5.3) - face/size
		ui/size: ui/size + delta + 8x10					;-- triggers a resizing event
	]

	update-ui: function [enabled? [logic!]][
		btn-send/enabled?: to-logic all [enabled? addr-list/selected > 0]
		if page > 0 [btn-prev/enabled?: enabled?]
		foreach f [btn-more net-list token-list page-info btn-reload][
			set in get f 'enabled? enabled?
		]
		process-events
	]

	copy-addr: func [/local addr][
		if btn-send/enabled? [
			addr: pick addr-list/data addr-list/selected 
			write-clipboard copy/part addr find addr space
		]
	]

	do-more-addr: func [face event][
		unless connected? [exit]
		page-info/selected: page + 2					;-- page is zero-based
		list-addresses/next
		if page > 0 [btn-prev/enabled?: yes]
	]

	do-prev-addr: func [face event][
		unless connected? [exit]
		if page = 1 [
			btn-prev/enabled?: no
			process-events
		]
		page-info/selected: page
		list-addresses/prev
	]
	
	do-page: func [face event][	
		page: (to-integer pick face/data face/selected) - 1
		if zero? page [btn-prev/enabled?: no]
		list-addresses
	]

	do-send: func [face [object!] event [event!]][
		either any [token-name = "ETH" token-name = "RED"][
			eth-ui/do-send face event
		][
			btc-ui/do-send face event
		]
	]

	ui: layout compose [
		title "RED Wallet"
		text 50 "Device:"
		dev-list: drop-list data key/get-valid-names 135 select 1 :do-select-dev
		btn-send: button "Send" :do-send disabled
		token-list: drop-list data tokens 60 select 1 :do-select-token
		net-list:   drop-list data net-names select 2 :do-select-network
		btn-reload: button "Reload" :do-reload disabled
		return
		
		text bold "My Addresses" pad 280x0 
		text bold "Balances" right return pad 0x-10
		
		addr-list: text-list font list-font 520x100 return middle
		
		info-msg: text 285x20
		text right 50 "Page:" tight
		page-info: drop-list 40 
			data collect [repeat p 10 [keep form p]]
			select (page + 1)
			:do-page
		btn-prev: button "Prev" disabled :do-prev-addr 
		btn-more: button "More" :do-more-addr
	]

	unlock-dev-dlg: layout [
		title "Unlock your key"
		text font-size 12 {Unlock your Ledger key, open the Ethereum app, ensure "Browser support" is "No".}
		return
		pad 262x10 button "OK" [unview]
	]

	contract-data-dlg: layout [
		title "Set Contract data to YES"
		text font-size 12 {Please set "Contract data" to "Yes" in the Ethereum app's settings.}
		return
		pad 180x10 button "OK" [unview]
	]

	nonce-error-dlg: layout [
		title "Cannot get nonce"
		text font-size 12 {Cannot get nonce, please try again.}
		return
		pad 110x10 button "OK" [unview]
	]

	tx-error-dlg: layout [
		title "Send Transaction Error"
		tx-error: area 400x200
	]

	support-device?: func [
		id			[integer!]
		return:		[logic!]
	][
		key/support? id
	]

	monitor-devices: does [
		append ui/pane usb-device: make face! [
			type: 'usb-device offset: 0x0 size: 10x10 rate: 0:0:1
			actors: object [
				on-up: func [face [object!] event [event!] /local id [integer!] len [integer!]][
					id: face/data/2 << 16 or face/data/1
					if support-device? id [
						;-- print "on-up"
						enumerate-connected-devices
						len: length? dev-list/data
						either len > 1 [								;-- if we have multi devices, just reset all
							;-- print [len " devices"]
							face/rate: none
							connected?: no
							info-msg/text: ""
							key/close-pin-requesting-by-id id			;-- for trezor pin request
							key/close
							connect-device
							list-addresses
						][
							if any [
								not key/opened? id
								'Init = key/get-request-pin-state-by-id id
							][
								;-- print "need unlock key"
								connected?: no
								key/close
								connect-device
								list-addresses
							]
						]
						free-enumerate-connected-devices
					]
				]
				on-down: func [face [object!] event [event!] /local id [integer!]][
					id: face/data/2 << 16 or face/data/1
					if support-device? id [
						;-- print "on-down"
						face/rate: none
						connected?: no
						info-msg/text: ""
						clear addr-list/data
						key/close-pin-requesting-by-id id			;-- for trezor pin request
						key/close
						enumerate-connected-devices
						connect-device
						list-addresses
						free-enumerate-connected-devices
					]
				]
				on-time: func [face event /local name][
					name:  get-device-name
					if all [
						connected?
						'Requesting <> key/get-request-pin-state-by-name name
					][face/rate: none]
					;-- print "on-time"
					if not key/any-opened? [
						;-- print "need to enumerate"
						key/close
						enumerate-connected-devices
						connect-device
						free-enumerate-connected-devices
					]
					list-addresses
				]
			]
		]
	]

	setup-actors: does [
		ui/actors: context [
			on-close: func [face event][
				key/close
			]
			on-resizing: function [face event] [
				if any [event/offset/x < min-size/x event/offset/y < min-size/y][exit]
				do-resize event/offset - face/extra
				face/extra: event/offset
			]
		]

		addr-list/actors: make object! [
			on-menu: func [face [object!] event [event!]][
				switch event/picked [
					copy	[copy-addr]
				]
			]
			on-change: func [face event][
				address-index: page * addr-per-page + face/selected - 1
				btn-send/enabled?: to-logic face/selected
			]
		]

		addr-list/menu: [
			"Copy address"		copy
		]
	]

	run: does [
		eth-ui/init wallet
		btc-ui/init wallet
		min-size: ui/extra: ui/size
		setup-actors
		monitor-devices
		do-auto-size addr-list
		view/flags ui 'resize
	]
]

wallet/run
