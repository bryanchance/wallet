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

#if error? try [_int256_red_][
#do [_int256_red_: yes]

int256: context [

	system/catalog/errors/user: make system/catalog/errors/user [int256: ["int256 [" :arg1 ": (" :arg2 " " :arg3 ")]"]]

	new-error: func [name [word!] arg2 arg3][
		cause-error 'user 'int256 [name arg2 arg3]
	]

	empty: [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]

	make-i256: function [][
		make vector! compose/only [integer! 32 (empty)]
	]

	set 'to-i256 function [value [integer! float! binary! string! none!] return: [vector!]
		/local spec v n bin res factor f
	][
		switch/default type?/word value [
			integer! [
				either value >= 0 [
					spec: reduce [0 0 0 0 0 0 0 0 0 0 0 0 0 0 value / 65536 value % 65536]
				][
					return negative256 to-i256 (0 - value)
				]
			]
			float! [
				either value >= 0 [
					f: value
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
						if 16 < length? spec [new-error 'to-i256 "float too large" f]
						value: n
					]
					insert/dup spec 0 16 - length? spec
				][
					return negative256 to-i256 (0 - value)
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
					if 16 < length? spec [new-error 'to-i256 "binary too large" value]
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
				if any [value/1 = #"-" value/1 = #"+"] [
					bin: next value
				]
				while [all [not tail? bin bin/1 <> #"."]][
					if any [bin/1 < #"0" bin/1 > #"9"][new-error 'to-i256 "invalid char" bin/1]
					v: to-i256 to integer! (bin/1 - #"0")
					res: mul256 res factor
					res: add256 res v
					bin: next bin
				]
				if value/1 = #"-" [
					res: negative256 res
				]
				return res
			]
		][new-error 'to-i256 "invalid type" type?/word value]
		
		make vector! compose/only [integer! 32 (spec)]
	]

	set 'i256-to-int function [bigint [vector!] return: [integer!]
		/local neg? value high low res
	][
		neg?: negative256? bigint
		either neg? [
			value: negative256 bigint
		][
			value: bigint
		]
		if less-equal? (to-i256 7FFFFFFFh) value [new-error 'i256-to-int "too large" value]
		high: value/15 << 16
		low: value/16
		res: high + low
		if neg? [return 0 - res]
		res
	]

	set 'i256-to-float function [bigint [vector!] return: [float!]
		/local neg? value res p idx v
	][
		neg?: negative256? bigint
		either neg? [
			value: negative256 bigint
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

	set 'i256-to-bin function [bigint [vector!] return: [binary!]
		/local bin idx v
	][
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

	set 'i256-to-string function [bigint [vector!] return: [string!]
		/local neg? value res factor rest chr
	][
		res: make string! 64
		if bigint = to-i256 #{8000000000000000000000000000000000000000000000000000000000000000} [
			append res {-57896044618658097711785492504343953926634992332820282019728792003956564819968}
			return res
		]
		neg?: negative256? bigint
		either neg? [
			value: negative256 bigint
		][
			value: bigint
		]
		factor: to-i256 10
		rest: value
		forever [
			rest: div256/rem rest factor
			chr: to string! i256-to-int rest/2
			insert res chr
			if zero256? rest/1 [break]
			rest: rest/1
		]
		if neg? [
			insert res #"-"
		]
		res
	]

	set 'zero256? function [bigint [vector!] return: [logic!] /local idx][
		repeat idx length? bigint [if (bigint/:idx) <> 0 [return false]]
		true
	]

	set 'negative256? function [bigint [vector!] return: [logic!] /local idx][
		if bigint/1 and 8000h = 8000h [return true]
		false
	]

	u256-negative: func [bigint [vector!] return: [vector! map!]][
		sub256 to-i256 0 bigint
	]

	set 'negative256 function [bigint [vector!] return: [vector! map!]][
		u256-negative bigint
	]

	less-equal?: routine [
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
		if left = right [return yes]
		if all [negative256? left not negative256? right][return yes]
		if all [not negative256? left negative256? right][return no]
		if all [not negative256? left not negative256? right][return less-equal? left right]
		
		not less-equal? negative256 left negative256 right
	]

	set 'u256-lesser-or-equal? function [left [vector!] right [vector!] return: [logic!]][
		less-equal? left right
	]

	shift-left: routine [v [vector!] return: [integer!] /local	p [byte-ptr!] c [integer!]][
		p: vector/rs-head v
		c: (as-integer p/2) >>> 7
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
		c
	]

	set 'shl256 function [v [vector!]][
		shift-left v
		v
	]

	u256-add: routine [
		left  [vector!]
		right [vector!]
		res	  [vector!]
		return: [integer!]
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
		c
	]

	set 'add256 function [left [vector!] right [vector!] return: [vector!]
		/local res
	][
		u256-add left right res: make-i256
		if any [
			all [
				negative256? left
				negative256? right
				not negative256? res
			]
			all [
				not negative256? left
				not negative256? right
				negative256? res
			]
		][
			new-error 'add256 "overflow" reduce [left right res]
		]
		res
	]

	u256-sub: routine [
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

	set 'sub256 function [left [vector!] right [vector!] return: [vector!]
		/local res
	][
		u256-sub left right res: make-i256
		if any [
			all [
				negative256? left
				not negative256? right
				not negative256? res
			]
			all [
				not negative256? left
				negative256? right
				negative256? res
			]
		][
			new-error 'sub256 "overflow" reduce [left right res]
		]
		res
	]

	set 'mul256 function [left [vector!] right [vector!] return: [vector!]
		/local left-neg? left-abs right-neg? right-abs res-abs res
	][
		either left-neg?: negative256? left [
			left-abs: negative256 left
		][
			left-abs: left
		]
		either right-neg?: negative256? right [
			right-abs: negative256 right
		][
			right-abs: right
		]

		res-abs: try [u256-mul left-abs right-abs]
		if error? res-abs [
			either all [
				res-abs/arg1 = 'u256-mul
				res-abs/arg2 = "overflow"
			][
				res: pick res-abs/arg3 3
				if left-neg? <> right-neg? [
					res: negative256 res
				]
				new-error 'mul256 "overflow" reduce [left right res]
			][
				return res-abs
			]
		]

		either left-neg? <> right-neg? [
			res: negative256 res-abs
		][
			res: res-abs
		]
		res
	]

	u256-mul: func [left [vector!] right [vector!] return: [vector!]
		/local idx res s overflow? bigint-count i r bits res-new
	][
		idx: 16
		res: make-i256
		s: copy left
		overflow?: false
		bigint-count: valid-length? right
		repeat i bigint-count [
			r: right/:idx
			either i = bigint-count [
				bits: int16-valid-length? r
			][
				bits: 16
			]
			loop bits [
				if r and 1 <> 0 [
					if 0 <> u256-add res s res-new: make-i256 [
						overflow?: true
					]
					res: res-new
				]
				if 0 <> shift-left s [
					overflow?: true
				]
				r: shift r 1
			]
			idx: idx - 1
		]
		if overflow? [new-error 'u256-mul "overflow" reduce [left right res]]
		res
	]

	valid-length?: func [bigint [vector!] return: [integer!] /local i count][
		count: 0
		repeat i 16 [
			if bigint/(i) <> 0 [break]
			count: count + 1
		]
		16 - count
	]

	int16-valid-length?: func [int16 [integer!] return: [integer!] /local i mask count][
		count: 0
		repeat i 16 [
			mask: 1 << (16 - i)
			if mask = (int16 and mask) [break]
			count: count + 1
		]
		16 - count
	]

	u256-div: func [dividend [vector!] divisor [vector!] /rem return: [vector! block!]
		/local q r bigint-count idx d bit new-r
	][
		if zero256? divisor [new-error 'u256-div "zero-divide" reduce [dividend divisor]]

		q: make-i256
		r: make-i256
		bigint-count: valid-length? dividend
		repeat idx bigint-count [
			d: dividend/(16 - bigint-count + idx)
			bit: 15
			loop 16 [
				shl256 r
				r/16: r/16 or (1 and shift d bit)
				shl256 q
				if less-equal? divisor r [
					u256-sub r divisor new-r: make-i256
					r: new-r
					q/16: q/16 or 1
				]
				bit: bit - 1
			]
		]
		either rem [reduce [q r]][q]
	]

	set 'div256 function [dividend [vector!] divisor [vector!] /rem return: [vector! block!]
		/local dividend-neg? dividend-abs divisor-neg? divisor-abs res-abs q r
	][
		if zero256? divisor [new-error 'div256 "zero-divide" reduce [dividend divisor]]

		either dividend-neg?: negative256? dividend [
			dividend-abs: negative256 dividend
		][
			dividend-abs: dividend
		]
		either divisor-neg?: negative256? divisor [
			divisor-abs: negative256 divisor
		][
			divisor-abs: divisor
		]

		res-abs: u256-div/rem dividend-abs divisor-abs

		either dividend-neg? <> divisor-neg? [
			q: negative256 res-abs/1
		][
			q: res-abs/1
		]

		if rem [
			either zero256? res-abs/2 [
				r: res-abs/2
			][
				either dividend-neg? [r: sub256 divisor-abs res-abs/2][r: res-abs/2]
			]
			return reduce [q r]
		]
		q
	]

	set 'mod256 func [l [vector!] r [vector!] return: [vector!]][
		second div256/rem l r
	]
]

]
