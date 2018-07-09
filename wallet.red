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

#do [_wallet_red_: yes]
#if error? try [_config_red_] [#include %config.red]
#if error? try [_keys_red_] [#include %keys/keys.red]
#if error? try [_eth-api_red_] [#include %libs/eth-api.red]
#if error? try [_btc-api_red_] [#include %libs/btc-api.red]
#if error? try [_int256_red_] [#include %libs/int256.red]
#if error? try [_int-encode_red_] [#include %libs/int-encode.red]
#if error? try [_ui-base_red_] [#include %ui-base.red]
#if error? try [_eth-ui_red_] [#include %eth-ui.red]
#if error? try [_btc-ui_red_] [#include %btc-ui.red]



#system [
	with gui [#include %libs/usb-monitor.reds]
]

wallet: context [
	list-font:		make font! [name: get 'font-fixed size: 11]
	addr-per-page:	5
	min-size:		none
	connected?:		no
	page:			0

	;- layout item defined as local
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


	enumerate: func [/local len] [
		key/current/devices: key/enumerate
		if dev-list/selected > key/current/count [dev-list/selected: key/current/count]
		key/current/selected: dev-list/selected
		dev-list/data: key/current/name-list

		addr-list/data: []
	]


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
		if device-name = key/no-dev [
			info-msg/text: "Please plug in your key..."
			exit
		]
		if any [error? res: try [key/connect] res = none][
			info-msg/text: "Connect the key failed..."
			exit
		]

		if error? try [key/init][
			info-msg/text: "Initialize the key failed..."
			exit
		]
		if 'DeviceError = key/request-pin [
			info-msg/text: "Unlock the key failed..."
			exit
		]
		usb-device/rate: 0:0:1
		connected?: yes
	]

	list-addresses: func [
		/prev /next 
		/local
			n
			res
	][
		update-ui no

		if connected? [
			if 'DeviceError = key/get-request-pin-state [
				info-msg/text: "Unlock the key failed..."
				exit
			]
			if 'HasRequested <> key/get-request-pin-state [
				exit
			]

			info-msg/text: "Please wait while loading addresses..."

			if next [page: page + 1]
			if prev [page: page - 1]
			n: page * addr-per-page
			
			either any [token-name = "ETH" token-name = "RED"][
				clear eth-ui/addr-infos
				clear eth-ui/addresses
				addr-list/data: eth-ui/addresses
				loop addr-per-page [
					res: eth-ui/enum-address n
					info-msg/text: case [
						res = 'success [""]
						res = 'error [rejoin ["access " n " failed"]]
						res = 'browser-support-on [{Please set "Browser support" to "No"}]
						res = 'locked ["Please unlock your key"]]
					if res <> 'success [exit]
					process-events
					n: n + 1
				]
			][
				clear btc-ui/addr-infos
				clear btc-ui/addresses
				addr-list/data: btc-ui/addresses
				loop addr-per-page [
					res: btc-ui/enum-address n
					info-msg/text: case [
						res = 'success [""]
						res = 'error [rejoin ["access " n " failed"]]
						res = 'browser-support-on [{Please set "Browser support" to "No"}]
						res = 'locked ["Please unlock your key"]]
					if res <> 'success [exit]
					process-events
					n: n + 1
				]
			]

			if any [token-name = "ETH" token-name = "RED"][
				info-msg/text: "Please wait while loading balances..."
				eth-ui/current/infos: eth-ui/addr-infos
				either eth-ui/enum-address-info [
					info-msg/text: ""
				][
					info-msg/text: {Fetch balance: Timeout. Please try "Reload" again}
				]
			]
			update-ui yes
			do-auto-size addr-list
		]
	]

	do-select-dev: func [face [object!] event [event!]][
		key/close
		connected?: no
		face/selected: select-device face/selected
		connect
		list-addresses
	]

	do-select-network: func [face [object!] event [event!]][
		face/selected: select-net face/selected
		do-reload
	]

	do-select-token: func [face [object!] event [event!]][
		face/selected: select-token face/selected
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
			eth-ui/do-send face event
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
							if key/opened? [key/close]
							connected?: no
							connect
							list-addresses
						][
							if not key/opened? [
								;-- print "not opened"
								connected?: no
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
						face/rate: 0:0:1
						if key/opened? [key/close]
						connected?: no
						enumerate
						connect
						list-addresses
					]
				]
				on-time: func [face event][
					;-- print "on-time"
					if key/opened? [
						if 'Requesting = key/get-request-pin-state [list-addresses exit]
						if 'HasRequested = key/get-request-pin-state [face/rate: none list-addresses exit]
					]
					if key/opened? [key/close]
					connected?: no
					enumerate
					connect
					list-addresses
				]
			]
		]
	]

	setup-actors: does [
		ui/actors: context [
			on-close: func [face event][
				if key/opened? [key/close] connected?: no
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
				btn-send/enabled?: to-logic face/selected
				either any [token-name = "ETH" token-name = "RED"][
					eth-ui/current/selected: face/selected
				][
					btc-ui/current/selected: face/selected
				]
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

wallet/run
