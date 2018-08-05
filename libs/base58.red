Red [
	Title:	"base58 encode/decode"
	Author: "bitbegin"
	File: 	%base58.red
	Tabs: 	4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_base58_red_][
#do [_base58_red_: yes]

base58: context [

	system/catalog/errors/user: make system/catalog/errors/user [base58: ["base58 [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'base58 [name arg2 arg3]
	]

	decode-table: #{
		FF FF FF FF FF FF FF FF FF FF FF FF
		FF FF FF FF FF FF FF FF FF FF FF FF
		FF FF FF FF FF FF FF FF FF FF FF FF
		FF FF FF FF FF FF FF FF FF FF FF FF
		FF 00 01 02 03 04 05 06 07 08 FF FF
		FF FF FF FF FF 09 0A 0B 0C 0D 0E 0F
		10 FF 11 12 13 14 15 FF 16 17 18 19
		1A 1B 1C 1D 1E 1F 20 FF FF FF FF FF
		FF 21 22 23 24 25 26 27 28 29 2A 2B
		FF 2C 2D 2E 2F 30 31 32 33 34 35 36
		37 38 39 FF FF FF FF FF
	}

	encode-table: {123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz}

	tmp: make binary! 164
	buffer: make binary! 164


	decode: func [data [string!] return: [binary!]
		/local len tmp i j chr dechr zero-count start rem divloop dig256 tmp-div
	][
		len: length? data
		if 164 < len [cause-error 'decode "too long" len]
		tmp: to binary! data
		repeat i len [
			chr: pick data i
			if chr > 128 [cause-error 'decode "not char" chr]
			dechr: pick decode-table chr + 1
			poke tmp i dechr 
			if FFh = pick tmp i [cause-error 'decode "error index" i]
		]

		zero-count: 1
		while [
			all [
				zero-count <= len
				0 = pick tmp zero-count
			]
		][zero-count: zero-count + 1]

		loop 164 [
			append buffer 0
		]
		j: len + 1
		start: zero-count
		while [start <= len][
			rem: 0
			divloop: start
			while [divloop <= len][
				dig256: pick tmp divloop
				tmp-div: rem * 58 + dig256
				poke tmp divloop tmp-div / 256
				rem: tmp-div % 256
				divloop: divloop + 1
			]
			if 0 = pick tmp start [start: start + 1]
			j: j - 1
			poke buffer j rem
		]

		while [
			all [
				j <= len
				0 = pick buffer j
			]
		][
			j: j + 1
		]
		len: len - j + zero-count
		copy/part skip buffer j - zero-count len
	]

]

;-- probe try [base58/decode "1EfxCKm257NbVJhJCVMzyhkvuJh1j6Zyx"]
;-- 000295EC35D638C16B25608B4E362A214A5692D2005677274F

]
