Red [
	Title:	"eth ui and event process"
	Author: "bitbegin"
	File: 	%eth-ui.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_eth-ui_red_][
#do [_eth-ui_red_: yes]
#include %config.red
#include %keys/keys.red
#include %libs/eth-api.red
#include %libs/int256.red
#include %libs/int-encode.red
#include %ui-base.red

eth-ui: context [

	addr-infos: []
	addresses: []

	;- layout item defined as local
	network-to: none
	addr-from: none
	addr-to: none
	amount-field: none
	gas-price: none
	gas-limit: none
	btn-sign: none
	info-from: none
	info-to: none
	info-amount: none
	info-network: none
	info-price: none
	info-limit: none
	info-fee: none
	info-nonce: none

	signed-data: none

	gas-price-wei: none
	amount-wei: none

	current: make reactor! [
		infos: []
		selected: none
		count: is [length? infos]
		info: is [either selected [pick infos selected][none]]
		addr: is [either info [select info 'addr][none]]
		path: is [either info [select info 'path][none]]
		balance: is [either info [select info 'balance][none]]
	]

	enum-address: func [n [integer!] /local ids addr][
		ids: append copy bip-path n
		if error? addr: try [key/get-eth-address ids][
			return addr
		]

		if string? addr [
			append/only addr-infos reduce ['addr copy addr 'path ids]
			append addresses rejoin [addr "      <loading>"]
			return 'success
		]
		addr
	]

	enum-address-info: func [/local i len info][
		i: 1
		len: length? addr-infos
		until [
			info: pick addr-infos i
			if error? balance: try [eth-api/get-balance net-type network token-contract info/addr][
				return balance
			]
			poke addresses i rejoin [info/addr "   " form-i256 balance 18 18]
			;poke addr-infos i reduce ['addr info/addr 'path info/path 'balance balance]
			append info reduce ['balance balance]
			process-events
			i: i + 1
			i > len
		]
		'success
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
			gas-limit/text: either token-contract ["79510"]["21000"]
			if all [not error? gas-price-wei: try [eth-api/get-gas-price 'standard] gas-price-wei][
				gas-price/text: form-i256/nopad gas-price-wei 9 2
			]
			reset-sign-button
			label-unit/text: unit-name
			clear addr-to/text
			clear amount-field/text
			view/flags send-dialog 'modal
		]
	]

	check-data: func [/local addr amount balance sum][
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
		either all [
			vector? gas-price-wei: try [string-to-i256 gas-price/text 9]
			not negative256? gas-price-wei
			vector? amount-wei: try [string-to-i256 amount-field/text 18]
			not negative256? amount-wei
		][
			balance: current/balance
			sum: mul256 gas-price-wei to-i256 to integer! gas-limit/text
			sum: add256 sum amount-wei
			unless lesser-or-equal256? sum balance [
				amount-field/text: copy "Insufficient Balance"
				return no
			]
		][
			addr-to/text: copy "Invalid amount"
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

	do-sign-tx: func [face [object!] event [event!] /local tx nonce limit ids][
		unless check-data [exit]

		notify-user

		limit: to-integer gas-limit/text										;-- gas limit
		nonce: try [eth-api/get-nonce net-type network addr-from/text]		;-- nonce
		if error? nonce [
			unview
			view/flags nonce-error-dlg 'modal
			reset-sign-button
			exit
		]

		either token-contract [
			tx: reduce [
				nonce
				gas-price-wei
				limit
				debase/base token-contract 16			;-- to address
				eth-api/eth-to-wei to-i256 0			;-- value
				rejoin [								;-- data
					#{a9059cbb}							;-- method ID
					debase/base eth-api/pad64 copy skip addr-to/text 2 16
					eth-api/pad64 i256-to-bin amount-wei
				]
			]
		][
			tx: reduce [
				nonce
				gas-price-wei
				limit
				debase/base skip addr-to/text 2 16		;-- to address
				amount-wei
				#{}										;-- data
			]
		]

		signed-data: key/get-eth-signed-data current/path tx chain-id

		either all [
			signed-data
			binary? signed-data
		][
			info-from/text:		addr-from/text
			info-to/text:		copy addr-to/text
			info-amount/text:	rejoin [amount-field/text " " unit-name]
			info-network/text:	net-name
			info-price/text:	rejoin [gas-price/text " Gwei"]
			info-limit/text:	gas-limit/text
			info-fee/text:		rejoin [
				form-i256/nopad mul256 gas-price-wei to-i256 limit 18 8
				" Ether"
			]
			info-nonce/text: mold tx/1
			unview
			view/flags confirm-sheet 'modal
		][
			if signed-data = 'token-error [
				unview
				view/flags contract-data-dlg 'modal
			]
			reset-sign-button
		]
	]

	do-confirm: func [face [object!] event [event!] /local result][
		result: try [
			eth-api/publish-tx net-type network signed-data
		]
		unview
		either string? result [
			browse rejoin [explorer result]
		][
			ui-base/show-error-dlg result
		]
	]

	send-dialog: layout [
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
	]

	confirm-sheet: layout [
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
	]

	nonce-error-dlg: layout [
		title "Cannot get nonce"
		text font-size 12 {Cannot get nonce, please try again.}
		return
		pad 110x10 button "OK" [unview]
	]

	contract-data-dlg: layout [
		title "Set Contract data to YES"
		text font-size 12 {Please set "Contract data" to "Yes" in the Ethereum app's settings.}
		return
		pad 180x10 button "OK" [unview]
	]

]

]
