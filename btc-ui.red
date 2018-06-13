Red [
	Title:	"btc ui and event process"
	Author: "bitbegin"
	File: 	%btc-ui.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

btc-ui: context [
	ctx: wallet

	signed-data: get in ctx 'signed-data

	addr-list: get in ctx 'addr-list

	update-ui: get in ctx 'update-ui

	form-amount: get in ctx 'form-amount

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

	process-events: get in ctx 'process-events

	get-device-name: get in ctx 'get-device-name

	get-chain-id: get in ctx 'get-chain-id

	show-address: func [
		name			[string!]
		n				[integer!]
		addresses		[block!]
		/local
			addr		[string!]
	][
		res: key/get-btc-address name bip32-path n 0 network
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
		append addresses rejoin [addr "      " form-amount select res 'balance]
		addr-list/data: addresses
		return true
	]

	reset-sign-button: does [
		btn-sign/enabled?: yes
		btn-sign/offset/x: 215
		btn-sign/size/x: 60
		btn-sign/text: "Sign"
	]

	do-send: func [face [object!] event [event!] /local from dlg][
		if addr-list/data [
			if addr-list/selected = -1 [addr-list/selected: 1]
			dlg: send-dialog
			network-to/text: net-name
			from: pick addr-list/data addr-list/selected
			addr-from/text: copy/part from find from space
			fee/text: "229"
			reset-sign-button
			label-unit/text: token-name
			clear addr-to/text
			clear amount-field/text
			view/flags dlg 'modal
		]
	]

	check-data: func [/local addr amount balance from][
		addr: trim any [addr-to/text ""]
		unless all [
			addr/1 = #"0"
			addr/2 = #"x"
			26 < length? addr
			34 > length? addr
		][
			addr-to/text: copy "Invalid address"
			return no
		]
		amount: attempt [to float! amount-field/text]
		either all [amount amount > 0.0][
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
