Red [
	Title:	"eth ui and event process"
	Author: "bitbegin"
	File: 	%eth-ui.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

eth-ui: context [
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

	show-address: func [
		name			[string!]
		n				[integer!]
		addresses		[block!]
		/local
			addr		[string!]
			addr-list
	][
		addr: key/get-eth-address name bip32-path n
		if not string? addr [
			info-msg/text: case [
				addr = 'browser-support-on [{Please set "Browser support" to "No"}]
				addr = 'locked [
					usb-device/rate: 0:0:3
					"Please unlock your key"
				]
				true [{Please open the "Ethereum" application}]
			]
			update-ui yes
			return false
		]
		append addresses rejoin [addr "      <loading>"]
		addr-list: get-addr-list
		addr-list/data: addresses
		return true
	]

	enum-address-balance: func [
		/local
			address		[string!]
			addr		[string!]
			addr-list
			balance
	][
		info-msg/text: "Please wait while loading balances..."
		update-ui no
		either error? try [
			addr-list: get-addr-list
			foreach address addr-list/data [
				addr: copy/part address find address space
				balance: either token-contract [
					eth/get-balance-token network token-contract addr
				][
					eth/get-balance network addr
				]
				replace address "      <loading>" form-amount balance
				process-events
			]
		][
			info-msg/text: {Fetch balance: Timeout. Please try "Reload" again}
		][
			info-msg/text: ""
		]
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
			gas-limit/text: either token-contract ["79510"]["21000"]
			reset-sign-button
			label-unit/text: token-name
			clear addr-to/text
			clear amount-field/text
			view/flags dlg 'modal
		]
	]

	check-data: func [/local addr amount balance from addr-list][
		addr: trim any [addr-to/text ""]
		unless all [
			addr/1 = #"0"
			addr/2 = #"x"
			42 = length? addr
			debase/base skip addr 2 16
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

		price: eth/gwei-to-wei gas-price/text			;-- gas price
		limit: to-integer gas-limit/text				;-- gas limit
		amount: eth/eth-to-wei amount-field/text		;-- send amount
		nonce: eth/get-nonce network addr-from/text		;-- nonce
		if nonce = -1 [
			unview
			view/flags nonce-error-dlg 'modal
			reset-sign-button
			exit
		]

		name: get-device-name
		;-- Edge case: key may locked in this moment
		unless string? key/get-eth-address name bip32-path 0 [
			reset-sign-button
			view/flags unlock-dev-dlg 'modal
			exit
		]

		either token-contract [
			tx: reduce [
				nonce
				price
				limit
				debase/base token-contract 16			;-- to address
				eth/eth-to-wei 0						;-- value
				rejoin [								;-- data
					#{a9059cbb}							;-- method ID
					debase/base eth/pad64 copy skip addr-to/text 2 16
					eth/pad64 i256-to-bin amount
				]
			]
		][
			tx: reduce [
				nonce
				price
				limit
				debase/base skip addr-to/text 2 16		;-- to address
				amount
				#{}										;-- data
			]
		]

		signed-data: key/get-eth-signed-data name bip32-path address-index tx get-chain-id

		either all [
			signed-data
			binary? signed-data
		][
			dlg: confirm-sheet
			info-from/text:		addr-from/text
			info-to/text:		copy addr-to/text
			info-amount/text:	rejoin [amount-field/text " " token-name]
			info-network/text:	net-name
			info-price/text:	rejoin [gas-price/text " Gwei"]
			info-limit/text:	gas-limit/text
			info-fee/text:		rejoin [
				mold (to float! gas-price/text) * (to float! gas-limit/text) / 1e9
				" Ether"
			]
			info-nonce/text: mold tx/1
			unview
			view/flags dlg 'modal
		][
			if signed-data = 'token-error [
				unview
				view/flags contract-data-dlg 'modal
			]
			reset-sign-button
		]
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
		title "Send Ether & Tokens"
		style label: text  100 middle
		style lbl:   text  360 middle font [name: font-fixed size: 10]
		style field: field 360 font [name: font-fixed size: 10]
		label "Network:"		network-to:	  lbl return
		label "From Address:"	addr-from:	  lbl return
		label "To Address:"		addr-to:	  field return
		label "Amount to Send:" amount-field: field 120 label-unit: label 50 return
		label "Gas Price:"		gas-price:	  field 120 "21" return
		label "Gas Limit:"		gas-limit:	  field 120 "21000" return
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
		label "Gas Price:" 		info-price:	  info return
		label "Gas Limit:" 		info-limit:	  info return
		label "Max TX Fee:" 	info-fee:	  info return
		label "Nonce:"			info-nonce:	  info return
		pad 164x10 button "Cancel" [signed-data: none unview] button "Send" :do-confirm
	]]
]
