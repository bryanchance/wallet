Red [
	Title:	"Library for communication with HID devices"
	Author: "Xie Qingtian"
	File: 	%hidapi.red
	Tabs: 	4
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#if error? try [_hidapi_red_][
#do [_hidapi_red_: yes]

#system [
	#switch OS [
		Windows  [#include %windows.reds]
		macOS	 [#include %macOS.reds]
		#default []
	]

	int-to-bin*: func [int [integer!] bin [red-binary!]
		/local
			p	[int-ptr!]
			s	[series!]
	][
		s: GET_BUFFER(bin)
		p: as int-ptr! s/tail
		p/1: int
		s/tail: as cell! p + 1
	]
]

hid: context [

	system/catalog/errors/user: make system/catalog/errors/user [hid: ["hid [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'hid [name arg2 arg3]
	]

	enum-freed?: routine [return: [logic!]][
		hid/enum-freed?
	]

	enumerate: routine [
		ids			[block!]
		return:		[block!]
	][
		hid/enumerate* ids
	]

	free-enumeration: routine [][
		hid/free-enumeration
	]

	_open: routine [
		id			[integer!]
		index		[integer!]
		/local
			h		[int-ptr!]
	][
		if hid/enum-freed? [stack/set-last none-value]

		h: hid/open id index
		either null? h [
			stack/set-last none-value
		][
			handle/box as-integer h
		]
	]

	open: func [id [integer!] index [integer!] return: [handle!] /local res][
		unless res: _open id index [
			either enum-freed? [
				new-error 'open "no enum" reduce [id index]
			][
				new-error 'open "not found" reduce [id index]
			]
		]
		res
	]

	_read: routine [
		dev			[handle!]
		buffer		[binary!]
		timeout		[integer!]		;-- millisec
		return:		[integer!]
		/local
			s	[series!]
			p	[byte-ptr!]
			sz	[integer!]
	][
		s: GET_BUFFER(buffer)
		p: (as byte-ptr! s/offset) + buffer/head
		sz: hid/read-timeout as int-ptr! dev/value p s/size timeout
		if sz <> -1 [
			s/tail: as cell! (p + sz)
		]
		sz
	]

	read: func [dev [handle!] buffer [binary!] timeout [integer!] return: [integer!] /local res][
		res: _read dev buffer timeout
		if res = -1 [new-error 'read "error" dev]
		res
	]

	_write: routine [
		dev			[handle!]
		data		[binary!]
		return:		[integer!]
		/local
			sz		[integer!]
	][
		sz: hid/write as int-ptr! dev/value binary/rs-head data binary/rs-length? data
		sz
	]

	write: func [dev [handle!] data [binary!] return: [integer!] /local res][
		res: _write dev data
		if res = -1 [new-error 'write "error" dev]
		res
	]

	close: routine [
		dev		[handle!]
	][
		if dev/value <> 0 [hid/close as int-ptr! dev/value]
	]
]

]
