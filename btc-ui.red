Red [
	Title:	"btc ui and event process"
	Author: "bitbegin"
	File: 	%btc-ui.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

btc-ui: context [
	ctx: none

	init: func [new-ctx][
		ctx: new-ctx
	]

	get-signed-data: does [
		get in ctx 'signed-data
	]

	get-addr-list: does [
		get in ctx 'addr-list
	]

	update-ui: func [value /local f][
		f: get in ctx 'update-ui
		do [f value]
	]

	form-amount: func [value /local f][
		f: get in ctx 'form-amount
		do [f value]
	]

	token-name: does [
		get in ctx 'token-name
	]
	net-name: does [
		get in ctx 'net-name
	]
	network: does [
		get in ctx 'network
	]
	explorer: does [
		get in ctx 'explorer
	]
	token-contract: does [
		get in ctx 'token-contract
	]
	bip32-path: does [
		get in ctx 'bip32-path
	]

	process-events: has [f][
		f: get in ctx 'process-events
		do [f]
	]

	get-device-name: has [f][
		f: get in ctx 'get-device-name
		do [f]
	]

	get-chain-id: has [f][
		f: get in ctx 'get-chain-id
		do [f]
	]

	address-index: does [
		get in ctx 'address-index
	]

	account-info: make map! []
	addr-balances: []

	get-account-balance: func [
		name			[string!]
		bip32-path		[block!]
		account			[integer!]
		return:			[map! word!]
		/local
			ids
			c-list o-list len i addr txs balance total btc-res
	][
		clear account-info
		ids: copy bip32-path
		poke ids 3 (80000000h + account)
		append ids 0

		c-list: copy []
		o-list: copy []

		total: to-i256 0

		;-- change address
		ids/4: 1
		i: 0
		forever [
			process-events
			ids/5: i
			addr: key/get-btc-address name ids
			if block? addr [return reduce ['get-account-balance addr]]

			btc-res: btc/balance-empty? network addr
			process-events
			if word? btc-res [return 'error]
			if true = btc-res [
				append c-list reduce [addr none]
				put account-info 'change c-list
				break
			]

			txs: btc/get-tx-hash network addr
			process-events
			if word? txs [return 'error]
			if txs = [][
				append c-list reduce [addr to-i256 0]
				put account-info 'change c-list
				i: i + 1
				continue
			]

			balance: btc/get-last-balance
			append c-list reduce [addr balance]
			total: add256 total balance

			i: i + 1
		]

		;-- origin address
		ids/4: 0
		i: 0
		forever [
			process-events
			ids/5: i
			addr: key/get-btc-address name ids
			if block? addr [return reduce ['get-account-balance addr]]

			btc-res: btc/balance-empty? network addr
			process-events
			if word? btc-res [return 'error]
			if true = btc-res [
				append o-list reduce [addr none]
				put account-info 'origin o-list
				break
			]

			txs: btc/get-tx-hash network addr
			process-events
			if word? txs [return 'error]
			if txs = [][
				append o-list reduce [addr to-i256 0]
				put account-info 'origin o-list
				i: i + 1
				continue
			]

			balance: btc/get-last-balance
			append o-list reduce [addr balance]
			total: add256 total balance

			i: i + 1
		]

		total: i256-to-float total
		total: total / 1e8
		put account-info 'balance total
		account-info
	]

	show-address: func [
		name			[string!]
		n				[integer!]
		addresses		[block!]
		/local
			addr		[string!]
			addr-list
			res
	][
		res: get-account-balance name bip32-path n
		either map? res [
			addr: pick back back tail select res 'origin 1
		][
			addr: res
		]
		if not string? addr [
			info-msg/text: case [
				addr = 'browser-support-on [{Please set "Browser support" to "No"}]
				addr = 'locked [
					usb-device/rate: 0:0:3
					"Please unlock your key"
				]
				true [{Get Address Failed!}]
			]
			update-ui yes
			return false
		]
		append addr-balances account-info
		append addresses rejoin [addr "      " form-amount select res 'balance]
		addr-list: get-addr-list
		addr-list/data: addresses
		return true
	]

	reset-sign-button: does [
		btn-sign/enabled?: yes
		btn-sign/offset/x: 215
		btn-sign/size/x: 60
		btn-sign/text: "Sign"
	]

	do-send: func [face [object!] event [event!] /local from dlg addr-list][
		addr-list: get-addr-list
		if addr-list/data [
			if addr-list/selected = -1 [addr-list/selected: 1]
			dlg: send-dialog
			network-to/text: net-name
			from: pick addr-list/data addr-list/selected
			addr-from/text: copy/part from find from space
			fee/text: "229"
			reset-sign-button
			label-unit/text: "BTC"    ;token-name
			clear addr-to/text
			clear amount-field/text
			view/flags dlg 'modal
		]
	]

	check-data: func [/local addr amount balance from addr-list][
		addr: trim any [addr-to/text ""]
		unless all [
			26 <= length? addr
			34 >= length? addr
		][
			addr-to/text: copy "Invalid address"
			return no
		]
		amount: attempt [to float! amount-field/text]
		either all [amount amount > 0.0][
			addr-list: get-addr-list
			from: pick addr-list/data addr-list/selected
			balance: to float! find/tail from space
			if amount > balance [
				amount-field/text: copy "Insufficient Balance"
				return no
			]
		][
			amount-field/text: copy "Invalid amount"
			return no
		]
		yes
	]

	notify-user: does [
		btn-sign/enabled?: no
		process-events
		btn-sign/offset/x: 133
		btn-sign/size/x: 225
		btn-sign/text: "Confirm the transaction on your device"
		process-events
	]

	do-sign-tx: func [face [object!] event [event!] /local tx nonce price limit amount name dlg][
		unless check-data [exit]

		notify-user


	]

	do-confirm: func [face [object!] event [event!] /local result][
		result: eth/call-rpc network 'eth_sendRawTransaction reduce [
			rejoin ["0x" enbase/base signed-data 16]
		]
		unview
		either string? result [
			browse rejoin [explorer result]
		][							;-- error
			tx-error/text: rejoin ["Error! Please try again^/^/" form result]
			view/flags tx-error-dlg 'modal
		]
	]

	send-dialog: does [layout [
		title "Send Bitcoin"
		style label: text  100 middle
		style lbl:   text  360 middle font [name: font-fixed size: 10]
		style field: field 360 font [name: font-fixed size: 10]
		label "Network:"		network-to:	  lbl return
		label "From Address:"	addr-from:	  lbl return
		label "To Address:"		addr-to:	  field return
		label "Amount to Send:" amount-field: field 120 label-unit: label 50 return
		label "Fee:"			fee:		  field 120 "229" return
		pad 215x10 btn-sign: button 60 "Sign" :do-sign-tx
	]]

	confirm-sheet: does [layout [
		title "Confirm Transaction"
		style label: text 120 right bold 
		style info: text 330 middle font [name: font-fixed size: 10]
		label "From Address:" 	info-from:    info return
		label "To Address:" 	info-to: 	  info return
		label "Amount to Send:" info-amount:  info return
		label "Network:"		info-network: info return
		label "Fee:" 			info-fee:	  info return
		label "Nonce:"			info-nonce:	  info return
		pad 164x10 button "Cancel" [signed-data: none unview] button "Send" :do-confirm
	]]
]

