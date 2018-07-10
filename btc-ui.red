Red [
	Title:	"btc ui and event process"
	Author: "bitbegin"
	File: 	%btc-ui.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#do [_btc-ui_red_: yes]
#if error? try [_config_red_] [#include %config.red]
#if error? try [_keys_red_] [#include %keys/keys.red]
#if error? try [_eth-api_red_] [#include %libs/eth-api.red]
#if error? try [_int256_red_] [#include %libs/int256.red]
#if error? try [_int-encode_red_] [#include %libs/int-encode.red]
#if error? try [_ui-base_red_] [#include %ui-base.red]

btc-ui: context [

	addr-infos: []
	addresses: []

	input-amount: none
	input-fee: none
	input-addr: none

	;- layout item defined as local
	network-to: none
	addr-from: none
	addr-to: none
	amount-field: none
	tx-fee: none
	btn-sign: none
	info-from: none
	info-to: none
	info-amount: none
	info-network: none
	info-fee: none
	info-rate: none
	info-fee: none

	current: make reactor! [
		infos: []
		selected: none
		count: is [length? infos]
		info: is [either selected [pick infos selected][none]]
		addr: is [either info [select last info/origin 'addr][none]]
		balance: is [either info [select info 'balance][none]]
	]

	enum-address-info: func [
		path			[block!]
		account			[integer!]
		return:			[block!]
		/local
			ids
			list c-list o-list len i addr utxs balance total
	][
		ids: copy path
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
			addr: key/get-btc-address ids
			balance: btc-api/get-balance network addr
			process-events
			if balance = none [
				append/only c-list reduce ['addr addr 'path copy ids]
				append list reduce ['change c-list]
				break
			]

			utxs: btc-api/get-unspent network addr
			process-events
			if utxs = none [
				append/only c-list reduce ['addr addr 'balance to-i256 0 'path copy ids]
				i: i + 1
				continue
			]

			append/only c-list reduce ['addr addr 'utxs utxs 'balance balance 'path copy ids]
			total: add256 total balance

			i: i + 1
		]

		;-- origin address
		ids/4: 0
		i: 0
		forever [
			process-events
			ids/5: i
			addr: key/get-btc-address ids
			balance: btc-api/get-balance network addr
			process-events
			if balance = none [
				append/only o-list reduce ['addr addr 'path copy ids]
				append list reduce ['origin o-list]
				break
			]

			utxs: btc-api/get-unspent network addr
			process-events
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

	enum-address: func [n [integer!] /local res addr][
		if error? res: try [enum-address-info bip-path n] [
			return 'error
		]

		append/only addr-infos res
		addr: select last res/origin 'addr
		append/dup addr #" " 42 - length? addr
		append addresses rejoin [addr form-i256 res/balance 8 8]
		current/infos: addr-infos
		return 'success
	]

	reset-sign-button: does [
		btn-sign/enabled?: yes
		btn-sign/offset/x: 215
		btn-sign/size/x: 60
		btn-sign/text: "Sign"
	]

	do-send: func [face [object!] event [event!]][
		if addresses [
			if current/selected = none [current/selected: 1]
			network-to/text: net-name
			addr-from/text: current/addr
			reset-sign-button
			label-unit/text: unit-name
			fee-unit/text: unit-name
			clear addr-to/text
			clear amount-field/text
			view/flags send-dialog 'modal
		]
	]

	check-data: does [
		input-addr: trim any [addr-to/text ""]
		unless all [
			26 <= length? input-addr
			36 >= length? input-addr
		][
			addr-to/text: copy "Invalid address"
			return no
		]

		input-amount: string-to-i256 amount-field/text 8
		input-fee: string-to-i256 tx-fee/text 8

		if string? input-amount [
			amount-field/text: copy "Invalid amount"
			return no
		]

		if string? input-fee [
			tx-fee/text: copy "Invalid fee"
			return no
		]

		if not lesser-or-equal256? (add256 input-amount input-fee) current/balance [
			amount-field/text: copy "Insufficient Balance"
			return no
		]

		yes
	]

	calc-balance: func [
		account				[block!]
		amount				[vector!]
		fee					[vector!]
		addr-to				[string!]
		/local utx
	][
		utx: calc-balance-by-largest account amount fee addr-to
		if utx = none [
			utx: calc-balance-by-order account amount fee addr-to
		]
		probe utx
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
					info: btc-api/get-tx-info network utx/tx-hash
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
					info: btc-api/get-tx-info network utx/tx-hash
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
				info: btc-api/get-tx-info network utx/tx-hash
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
				info: btc-api/get-tx-info network utx/tx-hash
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
		ui/process-events
		btn-sign/offset/x: 133
		btn-sign/size/x: 225
		btn-sign/text: "Confirm the transaction on your device"
		ui/process-events
	]

	do-sign-tx: func [face [object!] event [event!] /local utx rate][
		unless check-data [exit]

		;-- Edge case: key may locked in this moment
		unless string? key/get-btc-address append copy bip-path 0 [
			reset-sign-button
			view/flags unlock-dev-dlg 'modal
			exit
		]

		utx: calc-balance current/info input-amount input-fee input-addr
		if utx = none [
			amount-field/text: copy "NYI.!"
			return no
		]

		notify-user

		signed-data: key/get-btc-signed-data utx
		either all [
			signed-data
			binary? signed-data
		][
			info-from/text:		addr-from/text
			info-to/text:		copy addr-to/text
			info-amount/text:	rejoin [amount-field/text " " unit-name]
			info-network/text:	net-name
			info-fee/text:		rejoin [tx-fee/text " " unit-name]
			rate: to integer! ((to float! tx-fee/text)  * 1e9 / length? signed-data)
			info-rate/text:		rejoin [form rate / 10.0 " sat/B"]
			unview
			view/flags confirm-sheet 'modal
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
		if error? txid: try [btc-api/decode-tx network datas][
			ui-base/tx-error/text: rejoin ["Error! Please try again^/^/" form txid]
			view/flags ui-base/tx-error-dlg 'modal
			exit
		]
		either error? result: try [btc-api/publish-tx network datas][
			unview
			ui-base/tx-error/text: rejoin ["Error! Please try again^/^/" form result]
			view/flags ui-base/tx-error-dlg 'modal
		][
			unview
			browse rejoin [explorer txid/1]
		]
	]

	send-dialog: layout [
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
	]

	confirm-sheet: layout [
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
	]
]

