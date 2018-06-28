Red [
	Title:	"integer encode/decode"
	Author: "bitbegin"
	File: 	%int-encode.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

to-bin8: func [v [integer! char!]][
	to binary! to char! 256 + v and 255
]

to-bin16: func [v [integer! char!]][	;-- big-endian encoding
	skip to-binary to-integer v 2
]

to-bin32: func [v [integer! char!]][	;-- big-endian encoding
	to-binary to-integer v
]

to-int16: func [b [binary!]][
	to-integer copy/part b 2
]

to-int32: func [b [binary!]][
	to-integer copy/part b 4
]

string-to-i256: func [s [string!] scalar [integer!] return: [vector!]
	/local dot left right
][
	either dot: find s #"." [
		left: copy/part s dot
		right: copy next dot
	][
		left: copy s
		right: copy ""
	]

	append/dup right #"0" (scalar - length? right)
	append left right
	to-i256 left
]
