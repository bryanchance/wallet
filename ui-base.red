Red [
	Title:	"wallet ui base"
	Author: "bitbegin"
	File: 	%ui-base.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#do [_ui-base_red_: yes]
#if error? try [_config_red_] [#include %config.red]
#if error? try [_keys_red_] [#include %keys/keys.red]

#system [
	with gui [#include %libs/usb-monitor.reds]
]

ui-base: context [
	list-font:		make font! [name: get 'font-fixed size: 11]
	addr-per-page:	5
	min-size:		none
	connected?:		no
	address-index:	0
	page:			0

	;- layout item as local
	dev-list: none
	btn-send: none
	token-list: none
	net-list: none
	btn-reload: none
	addr-list: none
	info-msg: none
	page-info: none
	btn-prev: none
	btn-more: none
	tx-error: none

	enumerate: func [/local len] [
		key/current/devices: key/enumerate
		if dev-list/selected > key/current/count [dev-list/selected: key/current/count]
		key/current/selected: dev-list/selected
		dev-list/data: key/current/name-list

		if dev-list/data/1 = key/no-dev [
			info-msg/text: "Please plug in your key..."
			clear addr-list/data
		]
	]

	process-events: does [loop 10 [do-events/no-wait]]

	update-ui: func [enabled? [logic!]][
		btn-send/enabled?: to-logic all [enabled? addr-list/selected > 0]
		if page > 0 [btn-prev/enabled?: enabled?]
		foreach f [btn-more net-list token-list page-info btn-reload][
			set in get f 'enabled? enabled?
		]
		process-events
	]

	connect: has [res][
		update-ui no

		if any [error? res: try [key/connect] res = none][
			info-msg/text: "Connect the key failed..."
			exit
		]

		if error? try [key/init][
			info-msg/text: "Initialize the key failed..."
			exit
		]

		if 'DeviceError = key/request-pin 'no-wait [
			info-msg/text: "Unlock the key failed..."
			exit
		]

		usb-device/rate: none
		connected?: yes
	]

	list-addresses: func [
		/prev /next 
		/local
			addr n
			res
	][
		update-ui no

		if connected? [
			if 'DeviceError = key/get-request-pin-state [
				info-msg/text: "Unlock the key failed..."
				exit
			]

			info-msg/text: "Please wait while loading addresses..."

			if next [page: page + 1]
			if prev [page: page - 1]
			n: page * addr-per-page
			
			loop addr-per-page [
				either any [token-name = "ETH" token-name = "RED"][
					;-- if not eth-ui/show-address name n [exit]
					process-events
					n: n + 1
				][
					;-- if not btc-ui/show-address name n [exit]
					process-events
					n: n + 1
				]
			]
			if any [token-name = "ETH" token-name = "RED"][
				;-- eth-ui/enum-address-balance
			]
			update-ui yes
			do-auto-size addr-list
			info-msg/text: ""
		]
	]

	do-select-dev: func [face [object!] event [event!]][
		connected?: no
		key/close
		connect
		list-addresses
	]

	do-select-network: func [face [object!] event [event!]][
		select-net face/selected
		do-reload
	]

	do-select-token: func [face [object!] event [event!]][
		select-token face/selected
		net-list/selected: select-net net-list/selected
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
			;-- eth-ui/do-send face event
		][
			;-- btc-ui/do-send face event
		]
	]

	ui: layout compose [
		title "RED Wallet"
		text 50 "Device:"
		dev-list: drop-list data key/current/name-list 135 select key/current/selected :do-select-dev
		btn-send: button "Send" :do-send disabled
		token-list: drop-list data token-config/current/token-names 60 select token-config/current/token-selected :do-select-token
		net-list:   drop-list data token-config/current/net-names select token-config/current/net-selected :do-select-network
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

	monitor-devices: does [
		append ui/pane usb-device: make face! [
			type: 'usb-device offset: 0x0 size: 10x10 rate: 0:0:1
			actors: object [
				on-up: func [face [object!] event [event!] /local id [integer!] len [integer!]][
					id: face/data/2 << 16 or face/data/1
					if key/support? id [
						;-- print "on-up"
						enumerate
						len: length? dev-list/data
						either len > 1 [								;-- if we have multi devices, just reset all
							;-- print [len " devices"]
							face/rate: none
							connected?: no
							info-msg/text: ""
							key/close
							connect
							list-addresses
						][
							if any [
								device-id <> id
								'Init = key/get-request-pin-state
							][
								;-- print "need unlock key"
								connected?: no
								key/close
								connect
								list-addresses
							]
						]
					]
				]
				on-down: func [face [object!] event [event!] /local id [integer!]][
					id: face/data/2 << 16 or face/data/1
					if key/support? id [
						;-- print "on-down"
						face/rate: none
						connected?: no
						info-msg/text: ""
						clear addr-list/data
						key/close
						connect
						list-addresses
					]
				]
				on-time: func [face event][
					if all [
						connected?
						'Requesting <> key/get-request-pin-state
					][face/rate: none]
					;-- print "on-time"
					if not key/opened? [
						;-- print "need to enumerate"
						connect
					]
					list-addresses
				]
			]
		]
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
		min-size: ui/extra: ui/size
		setup-actors
		monitor-devices
		do-auto-size addr-list
		view/flags ui 'resize
	]
]
