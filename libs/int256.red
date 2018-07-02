Red [
	Title:	 "256-bit unsigned integer library"
	Author:	 "Nenad Rakocevic & bitbegin"
	File:	 %int256.red
	Tabs:	 4
	Rights:  "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]


int256: context [
	empty: [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]

	make-i256: function [][
		make vector! compose/only [integer! 32 (empty)]
	]

	set 'to-i256 function [value [integer! float! binary! string! none!] return: [vector! map!]][
		switch/default type?/word value [
			integer! [
				either value >= 0 [
					spec: reduce [0 0 0 0 0 0 0 0 0 0 0 0 0 0 value / 65536 value % 65536]
				][
					return sub256 to-i256 0 to-i256 (0 - value)
				]
			]
			float! [
				either value >= 0 [
					spec: make block! 16
					while [value <> 0.0][
						v: to integer! either value < 65536.0 [
							n: 0.0
							value
						][
							n: round/floor value / 65536.0
							value - (n * 65536.0)
						]
						insert spec v
						if 16 < length? spec [return chain-error/new 'to-i256 value "float too large" none]
						value: n
					]
					insert/dup spec 0 16 - length? spec
				][
					return sub256 to-i256 0 to-i256 (0 - value)
				]
			]
			binary! [
				bin: tail value
				spec: make block! 16

				while [not head? bin][
					bin: back bin
					v: bin/1
					unless head? bin [bin: back bin v: bin/1 << 8 + v]
					insert spec v
					if 16 < length? spec [return chain-error/new 'to-i256 value "binary too large" none]
				]
				insert/dup spec 0 16 - length? spec
			]
			string! [
				if value = {-57896044618658097711785492504343953926634992332820282019728792003956564819968} [
					spec: [32768 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
					return make vector! compose/only [integer! 32 (spec)]
				]
				res: to-i256 0
				factor: to-i256 10
				bin: value
				if value/1 = #"-" [
					bin: next value
				]
				while [all [not tail? bin bin/1 <> #"."]][
					if any [bin/1 < #"0" bin/1 > #"9"][return chain-error/new 'to-i256 bin/1 "invalid char" none]
					v: to-i256 to integer! (bin/1 - #"0")
					res: mul256 res factor
					if chain-error/error? res [return chain-error/new 'to-i256 bin/1 "mul256 overflow" res]
					res: add256 res v
					if chain-error/error? res [return chain-error/new 'to-i256 bin/1 "add256 overflow" res]
					bin: next bin
				]
				if value/1 = #"-" [
					res: sub256 to-i256 0 res
				]
				return res
			]
			none! [
				return to-i256 0
			]
		][return chain-error/new 'to-i256 none "invalid type" none]
		
		make vector! compose/only [integer! 32 (spec)]
	]

	set 'i256-to-int function [bigint [vector!] return: [integer! map!]
		/local
			idx value high low ret
	][
		neg?: i256-negative? bigint
		either neg? [
			value: sub256 to-i256 0 bigint
		][
			value: bigint
		]
		if less-equal256? (to-i256 7FFFFFFFh) value [return chain-error/new 'i256-to-int value "too large" none]
		high: value/15 << 16
		low: value/16
		ret: high + low
		if neg? [return 0 - ret]
		ret
	]

	set 'i256-to-float function [bigint [vector!] return: [float!]][
		neg?: i256-negative? bigint
		either neg? [
			value: sub256 to-i256 0 bigint
		][
			value: bigint
		]
		res: 0.0
		p: 1.0 
		idx: 16
		loop 16 [
			v: value/:idx
			res: v * p + res
			p: p * 65536.0
			idx: idx - 1
		]
		if neg? [return 0 - res]
		res
	]

	set 'i256-to-bin function [bigint [vector!] return: [binary!]][
		bin: make binary! 32
		idx: 16

		until [
			v: bigint/:idx
			insert bin v % 256
			insert bin v / 256
			zero? idx: idx - 1
		]
		bin
	]

	set 'i256-to-string function [bigint [vector!] return: [string! map!]
		/local
			neg? value res factor rest chr
	][
		res: make string! 64
		if bigint = to-i256 #{8000000000000000000000000000000000000000000000000000000000000000} [
			append res {-57896044618658097711785492504343953926634992332820282019728792003956564819968}
			return res
		]
		neg?: i256-negative? bigint
		either neg? [
			value: sub256 to-i256 0 bigint
		][
			value: bigint
		]
		factor: to-i256 10
		rest: value
		forever [
			rest: div256/rem rest factor
			if chain-error/error? rest [return chain-error/new 'i256-to-string none "div256 error" rest]
			chr: to string! i256-to-int rest/2
			insert res chr
			if i256-zero? rest/1 [break]
			rest: rest/1
		]
		if neg? [
			insert res #"-"
		]
		res
	]

	set 'i256-zero? function [bigint [vector!] return: [logic!] /local idx][
		repeat idx length? bigint [if (bigint/:idx) <> 0 [return false]]
		true
	]

	set 'i256-negative? function [bigint [vector!] return: [logic!] /local idx][
		if bigint/1 and 8000h = 8000h [return true]
		false
	]

	less-equal256?: routine [
		left	[vector!]
		right	[vector!]
		return: [logic!]
		/local
			pl [byte-ptr!]
			pr [byte-ptr!]
			p  [byte-ptr!]
			l  [integer!]
			r  [integer!]
			i  [integer!]
	][
		pl: vector/rs-head left
		pr: vector/rs-head right

		i: 1
		until [
			l: (as-integer pl/2) << 8 + as-integer pl/1
			r: (as-integer pr/2) << 8 + as-integer pr/1
			if l < r [return yes]
			if l > r [return no]
			pl: pl + 4
			pr: pr + 4
			i: i + 1
			any [i = 17 l <> r]
		]
		l = r
	]

	set 'lesser-or-equal256? function [left [vector!] right [vector!] return: [logic!]][
		less-equal256? left right
	]

	shift-left: routine [v [vector!] /local	p [byte-ptr!]][
		p: vector/rs-head v
		p/2: p/2 << 1 or (p/1 >>> 7)
		p/1: p/1 << 1 or (p/6 >>> 7)
		p/6: p/6 << 1 or (p/5 >>> 7)
		p/5: p/5 << 1 or (p/10 >>> 7)

		p/10: p/10 << 1 or (p/9 >>> 7)
		p/9:  p/9 << 1 or (p/14 >>> 7)
		p/14: p/14 << 1 or (p/13 >>> 7)
		p/13: p/13 << 1 or (p/18 >>> 7)

		p/18: p/18 << 1 or (p/17  >>> 7)
		p/17: p/17  << 1 or (p/22 >>> 7)
		p/22: p/22 << 1 or (p/21 >>> 7)
		p/21: p/21 << 1 or (p/26 >>> 7)

		p/26: p/26 << 1 or (p/25 >>> 7)
		p/25: p/25 << 1 or (p/30 >>> 7)
		p/30: p/30 << 1 or (p/29 >>> 7)
		p/29: p/29 << 1 or (p/34 >>> 7)

		p/34: p/34 << 1 or (p/33 >>> 7)
		p/33: p/33 << 1 or (p/38 >>> 7)
		p/38: p/38 << 1 or (p/37 >>> 7)
		p/37: p/37 << 1 or (p/42 >>> 7)

		p/42: p/42 << 1 or (p/41 >>> 7)
		p/41: p/41 << 1 or (p/46 >>> 7)
		p/46: p/46 << 1 or (p/45 >>> 7)
		p/45: p/45 << 1 or (p/50 >>> 7)

		p/50: p/50 << 1 or (p/49 >>> 7)
		p/49: p/49 << 1 or (p/54 >>> 7)
		p/54: p/54 << 1 or (p/53 >>> 7)
		p/53: p/53 << 1 or (p/58 >>> 7)

		p/58: p/58 << 1 or (p/57 >>> 7)
		p/57: p/57 << 1 or (p/62 >>> 7)
		p/62: p/62 << 1 or (p/61 >>> 7)
		p/61: p/61 << 1
	]

	set 'shl256 function [v [vector!]][
		shift-left v
		v
	]

	add-256: routine [
		left  [vector!]
		right [vector!]
		res	  [vector!]
		/local
			pl [byte-ptr!]
			pr [byte-ptr!]
			p  [byte-ptr!]
			l  [integer!]
			r  [integer!]
			v  [integer!]
			c  [integer!]
	][
		pl: (vector/rs-head left)  + 64
		pr: (vector/rs-head right) + 64
		p:  (vector/rs-head res)   + 64

		c: 0
		loop 16 [
			pl: pl - 4
			pr: pr - 4
			p:  p  - 4
			l: (as-integer pl/2) << 8 + as-integer pl/1
			r: (as-integer pr/2) << 8 + as-integer pr/1
			v: l + r + c
			c: as-integer v > 65535
			v: v and 65535
			p/1: as-byte v
			p/2: as-byte v >>> 8
		]
	]

	set 'add256 function [left [vector!] right [vector!] return: [vector!]][
		add-256 left right res: make-i256
		if any [
			all [
				i256-negative? left
				i256-negative? right
				not i256-negative? res
			]
			all [
				not i256-negative? left
				not i256-negative? right
				i256-negative? res
			]
		][
			return chain-error/new 'add256 res "overflow" none
		]
		res
	]

	sub-256: routine [
		left  [vector!]
		right [vector!]
		res	  [vector!]
		/local
			pl [byte-ptr!]
			pr [byte-ptr!]
			p  [byte-ptr!]
			l  [integer!]
			r  [integer!]
			v  [integer!]
			c  [integer!]
	][
		pl: (vector/rs-head left)  + 64
		pr: (vector/rs-head right) + 64
		p:  (vector/rs-head res)   + 64

		c: 0
		loop 16 [
			pl: pl - 4
			pr: pr - 4
			p:  p  - 4
			l: (as-integer pl/2) << 8 + as-integer pl/1
			r: (as-integer pr/2) << 8 + as-integer pr/1
			v: l - r - c								;-- borrowed carry bit
			c: as-integer l < (r + c)
			v: v and 65535
			p/1: as-byte v
			p/2: as-byte v >>> 8
		]
	]

	set 'sub256 function [left [vector!] right [vector!] return: [vector! map!]][
		sub-256 left right res: make-i256
		if any [
			all [
				i256-negative? left
				not i256-negative? right
				not i256-negative? res
			]
			all [
				not i256-negative? left
				i256-negative? right
				i256-negative? res
			]
		][
			return chain-error/new 'sub256 res "overflow" none
		]
		res
	]

	set 'mul256 function [left [vector!] right [vector!] return: [vector! map!]][
		idx: 16
		res: make-i256
		either i256-negative? left [s: sub256 to-i256 0 left][s: copy left]
		either i256-negative? right [right-raw: sub256 to-i256 0 right][right-raw: right]
		until [
			r: right-raw/:idx
			loop 16 [
				if r and 1 <> 0 [
					res: add256 res s
					if chain-error/error? res [return chain-error/new 'mul256 none "overflow" res]
				]
				shl256 s
				r: shift r 1
			]
			zero? idx: idx - 1
		]
		if (i256-negative? left) <> (i256-negative? right) [
			res: sub256 to-i256 0 res
		]
		res
	]

	set 'div256 function [dividend [vector!] divisor [vector!] /rem return: [vector! block! map!]][
		if i256-zero? divisor [return chain-error/new 'div256 divisor "zero-divide" none]
		
		q: make-i256
		r: make-i256
		either i256-negative? dividend [dividend-raw: sub256 to-i256 0 dividend][dividend-raw: dividend]
		either i256-negative? divisor [divisor-raw: sub256 to-i256 0 divisor][divisor-raw: divisor]
		repeat idx 16 [
			d: dividend-raw/:idx
			bit: 15
			loop 16 [
				shl256 r
				r/16: r/16 or (1 and shift d bit)
				shl256 q
				if less-equal256? divisor-raw r [
					r: sub256 r divisor-raw
					if chain-error/error? r [return chain-error/new 'div256 none "overflow" r]
					q/16: q/16 or 1
				]
				bit: bit - 1
			]
		]
		if (i256-negative? dividend) <> (i256-negative? divisor) [
			q: sub256 to-i256 0 q
		]
		either rem [reduce [q r]][q]
	]

	set 'mod256 func [l [vector!] r [vector!] return: [vector! map!]][
		res: div256/rem l r
		if chain-error/error? res [return chain-error/new 'mod256 none none res]
		second res
	]
]
