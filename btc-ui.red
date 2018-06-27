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
	coin-name: does [
		get in ctx 'coin-name
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

	unlock-dev-dlg: does [
		get in ctx 'unlock-dev-dlg
	]

	contract-data-dlg: does [
		get in ctx 'contract-data-dlg
	]

	nonce-error-dlg: does [
		get in ctx 'nonce-error-dlg
	]

	tx-error-dlg: does [
		get in ctx 'tx-error-dlg
	]

	addr-balances: []

	;-- change/orgin: [puk-hash utx balance bip32-path]
	get-account-balance: func [
		name			[string!]
		bip32-path		[block!]
		account			[integer!]
		return:			[block! string!]
		/local
			ids
			list c-list o-list len i addr utxs balance total
	][
		ids: copy bip32-path
		poke ids 3 (80000000h + account)
		append ids 0

		list: copy []
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
			if block? addr [return rejoin ["get-account-balance error: " form addr]]

			balance: btc/get-balance network addr
			process-events
			if string? balance [return balance]
			if balance = none [
				append/only c-list reduce ['addr addr 'path copy ids]
				append list reduce ['change c-list]
				break
			]

			utxs: btc/get-utxs network addr
			process-events
			if string? utxs [return utxs]
			if utxs = none [
				append/only c-list reduce ['addr addr 'balance to-i256 0 'path copy ids]
				i: i + 1
				continue
			]

			append/only c-list reduce ['addr addr 'utxs utxs 'balance balance 'path copy ids]
			total: add256 total balance

			i: i + 1
		]

		process-events

		;-- origin address
		ids/4: 0
		i: 0
		forever [
			process-events
			ids/5: i
			addr: key/get-btc-address name ids
			if block? addr [return rejoin ["get-account-balance error: " form addr]]

			balance: btc/get-balance network addr
			process-events
			if string? balance [return balance]
			if balance = none [
				append/only o-list reduce ['addr addr 'path copy ids]
				append list reduce ['origin o-list]
				break
			]

			utxs: btc/get-utxs network addr
			process-events
			if string? utxs [return utxs]
			if utxs = none [
				append/only o-list reduce ['addr addr 'balance to-i256 0 'path copy ids]
				i: i + 1
				continue
			]

			append/only o-list reduce ['addr addr 'utxs utxs 'balance balance 'path copy ids]
			total: add256 total balance

			i: i + 1
		]

		append list reduce ['balance total]
		list
	]

	show-address: func [
		name			[string!]
		n				[integer!]
		addresses		[block!]
		/local
			addr		[string!]
			balance
			addr-list
			res
	][
		res: get-account-balance name bip32-path n
		probe res
		either string? res [
			addr: 'error
		][
			addr: select last res/origin 'addr
		]
		if not string? addr [
			info-msg/text: case [
				addr = 'browser-support-on [{Please set "Browser support" to "No"}]
				addr = 'locked [
					usb-device/rate: 0:0:3
					"Please unlock your key"
				]
				addr = 'error [rejoin ["Get Address Failed: " res]]
				true ["Get Address Failed!"]
			]
			update-ui yes
			return false
		]
		balance: i256-to-float res/balance
		balance: balance / 1e8
		append/only addr-balances res
		append addresses rejoin [addr "      " form-amount balance]
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
			reset-sign-button
			label-unit/text: coin-name
			fee-unit/text: coin-name
			clear addr-to/text
			clear amount-field/text
			view/flags dlg 'modal
		]
	]

	check-data: func [/local addr amount balance from addr-list fee new-amount new-balance new-fee][
		addr: trim any [addr-to/text ""]
		unless all [
			26 <= length? addr
			36 >= length? addr
		][
			addr-to/text: copy "Invalid address"
			return no
		]
		amount: attempt [to float! amount-field/text]
		either all [amount amount > 0.0][
			addr-list: get-addr-list
			from: pick addr-list/data addr-list/selected
			balance: attempt [to float! find/tail from space]
			fee: attempt [to float! tx-fee/text]
			new-amount: to-i256 (amount * 1e8)
			new-balance: to-i256 (balance * 1e8)
			new-fee: to-i256 (fee * 1e8)
			if not lesser-or-equal256? (add256 new-amount new-fee) new-balance [
				amount-field/text: copy "Insufficient Balance"
				return no
			]
		][
			amount-field/text: copy "Invalid amount"
			return no
		]
		yes
	]

	calc-balance: func [
		account				[block!]
		amount				[float!]
		fee					[float!]
		addr-to				[string!]
		/local new-amount new-fee utx
	][
		new-amount: to-i256 (amount * 1e8)
		new-fee: to-i256 (fee * 1e8)
		utx: calc-balance-by-largest account new-amount new-fee addr-to
		if utx = none [
			utx: calc-balance-by-order account new-amount new-fee addr-to
		]
		utx
	]

	calc-balance-by-largest: func [
		account				[block!]
		amount				[vector!]
		fee					[vector!]
		addr-to				[string!]
		return:				[none! block!]
		/local change-addr-path ret inputs outputs total item utx info rest
	][
		change-addr-path: select last account/change 'path
		ret: copy []
		inputs: copy []
		outputs: copy []
		total: add256 amount fee

		foreach item account/change [
			if item/balance = none [break]
			if item/utxs = none [continue]

			foreach utx item/utxs [
				if lesser-or-equal256? total utx/value [
					info: btc/get-tx-info network utx/tx-hash
					append/only inputs reduce ['addr item/addr 'tx-hash utx/tx-hash 'path item/path 'info info]
					append/only outputs reduce ['addr addr-to 'value amount]
					rest: sub256 utx/value total
					if #{} <> trim/head i256-to-bin rest [
						append/only outputs reduce ['path change-addr-path 'value rest]
					]
					append ret reduce ['inputs inputs]
					append ret reduce ['outputs outputs]
					return ret
				]
			]
		]

		foreach item account/origin [
			if item/balance = none [break]
			if item/utxs = none [continue]

			foreach utx item/utxs [
				if lesser-or-equal256? total utx/value [
					info: btc/get-tx-info network utx/tx-hash
					append/only inputs reduce ['addr item/addr 'tx-hash utx/tx-hash 'path item/path 'info info]
					append/only outputs reduce ['addr addr-to 'value amount]
					rest: sub256 utx/value total
					if #{} <> trim/head i256-to-bin rest [
						append/only outputs reduce ['path change-addr-path 'value rest]
					]
					append ret reduce ['inputs inputs]
					append ret reduce ['outputs outputs]
					return ret
				]
			]
		]
		none
	]

	calc-balance-by-order: func [
		account				[block!]
		amount				[vector!]
		fee					[vector!]
		addr-to				[string!]
		return:				[none! block!]
		/local change-addr-path ret inputs outputs total sum item utx info rest
	][
		change-addr-path: select last account/change 'path
		ret: copy []
		inputs: copy []
		outputs: copy []
		total: add256 amount fee
		sum: to-i256 0

		foreach item account/change [
			if item/balance = none [break]
			if item/utxs = none [continue]

			foreach utx item/utxs [
				info: btc/get-tx-info network utx/tx-hash
				append/only inputs reduce ['addr item/addr 'tx-hash utx/tx-hash 'path item/path 'info info]
				sum: add256 sum utx/value
				if lesser-or-equal256? total sum [
					append/only outputs reduce ['addr addr-to 'value amount]
					rest: sub256 sum total
					if #{} <> trim/head i256-to-bin rest [
						append/only outputs reduce ['path change-addr-path 'value rest]
					]
					append ret reduce ['inputs inputs]
					append ret reduce ['outputs outputs]
					return ret
				]
			]
		]

		foreach item account/origin [
			if item/balance = none [break]
			if item/utxs = none [continue]

			foreach utx item/utxs [
				info: btc/get-tx-info network utx/tx-hash
				append/only inputs reduce ['addr item/addr 'tx-hash utx/tx-hash 'path item/path 'info info]
				sum: add256 sum utx/value
				if lesser-or-equal256? total sum [
					append/only outputs reduce ['addr addr-to 'value amount]
					rest: sub256 sum total
					if #{} <> trim/head i256-to-bin rest [
						append/only outputs reduce ['path change-addr-path 'value rest]
					]
					append ret reduce ['inputs inputs]
					append ret reduce ['outputs outputs]
					return ret
				]
			]
		]
		none
	]

	notify-user: does [
		btn-sign/enabled?: no
		process-events
		btn-sign/offset/x: 133
		btn-sign/size/x: 225
		btn-sign/text: "Confirm the transaction on your device"
		process-events
	]

	do-sign-tx: func [face [object!] event [event!] /local fee amount addr name addr-list utx rate][
		unless check-data [exit]

		fee: to float! tx-fee/text						;-- fee
		amount: to float! amount-field/text				;-- send amount
		addr: trim any [addr-to/text ""]

		name: get-device-name
		;-- Edge case: key may locked in this moment
		unless string? key/get-btc-address name append copy bip32-path 0 [
			reset-sign-button
			view/flags unlock-dev-dlg 'modal
			exit
		]

		addr-list: get-addr-list
		utx: calc-balance pick addr-balances addr-list/selected amount fee addr
		if utx = none [
			amount-field/text: copy "NYI.!"
			return no
		]

		probe utx

		notify-user

		signed-data: key/get-btc-signed-data name utx
		either all [
			signed-data
			binary? signed-data
		][
			dlg: confirm-sheet
			info-from/text:		addr-from/text
			info-to/text:		copy addr-to/text
			info-amount/text:	rejoin [amount-field/text " " coin-name]
			info-network/text:	net-name
			info-fee/text:		rejoin [tx-fee/text " " coin-name]
			rate: to integer! ((to float! tx-fee/text)  * 1e9 / length? signed-data)
			info-rate/text:		rejoin [form rate / 10.0 " sat/B"]
			unview
			view/flags dlg 'modal
		][
			if block? signed-data [
				unview
				view/flags contract-data-dlg 'modal
			]
			reset-sign-button
		]
	]

	do-confirm: func [face [object!] event [event!] /local datas txid result][
		datas: lowercase enbase/base signed-data 16
		txid: btc/decode-tx network datas
		if string? txid [
			tx-error/text: rejoin ["Error! Please try again^/^/" form txid]
			view/flags tx-error-dlg 'modal
			exit
		]
		result: btc/publish-tx network datas
		unview
		either string? result [
			tx-error/text: rejoin ["Error! Please try again^/^/" form result]
			view/flags tx-error-dlg 'modal
		][
			browse rejoin [explorer txid/1]
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
		label "Fee:"			tx-fee:		  field 120 "0.0001" fee-unit: label 50 return
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
		label "FeeRate:"		info-rate:	  info return
		pad 164x10 button "Cancel" [signed-data: none unview] button "Send" :do-confirm
	]]
]

