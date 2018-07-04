Red [
	Title:	"integer encode/decode"
	Author: "bitbegin"
	File: 	%int-encode.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#do [_int-encode_red_: yes]
#if error? try [_int256_red_] [#include %int256.red]

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

	either scalar >= length? right [
		append/dup right #"0" (scalar - length? right)
	][
		right: copy/part right scalar
	]

	append left right
	to-i256 left
]

form-i256: func [bigint [vector!] scalar [integer!] max-point [integer!] return: [string!]
	/local str abs len left right res
][
	abs: str: i256-to-string bigint
	if any [str/1 = #"-" str/1 = #"+"] [abs: next abs]

	len: length? abs
	either scalar >= len [
		left: "0"
		right: insert/dup copy abs #"0" (scalar - len)
	][
		left: copy/part abs len - scalar
		right: copy/part at abs (len + 1 - scalar) scalar
	]
	trim/tail/with right #"0"
	if right = "" [
		right: "0"
	]
	if all [left = "0" right = "0"][
		return "0"
	]
	if max-point < length? right [
		right: copy/part right max-point
	]
	res: rejoin [left "." right]
	if str/1 = #"-" [insert res #"-"]
	res
]
