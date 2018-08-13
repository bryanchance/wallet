Red [
	Title:	"btc-addr"
	Author: "bitbegin"
	File: 	%btc-addr.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_btc-addr_red_][
#do [_btc-addr_red_: yes]
#include %ripemd160.red

btc-addr: context [
	prefix: [
		'P2PKH				0
		'P2SH				5
		'PRIV				80h
		'BIP32-PUBKEY		0488B21Eh
		'BIP32-PRIKEY		0488ADE4h
		'TEST-P2PKH			6Fh
		'TEST-P2SH			C4h
		'TEST-PRIV			EFh
		'TEST-BIP32-PUBKEY	043587CFh
		'TEST-BIP32-PRIKEY	04358394h
	]

	base58check: func [data [binary!] return: [string!]][
		append data copy/part checksum checksum data 'sha256 'sha256 4
		enbase/base data 58
	]

	pubkey-to-hash: func [pubkey [binary!] return: [binary!]][
		ripemd160 checksum pubkey 'sha256
	]

	pubkey-to-addr: func [pubkey [binary!] type [word!] return: [string!]
		/local hash
	][
		hash: pubkey-to-hash pubkey
		insert hash select prefix type
		base58check hash
	]

	pubkey-to-segwit-addr: func [pubkey [binary!] type [word!] return: [string!]][
		pubkey-to-addr pubkey-to-script pubkey type
	]

	pubkey-to-script: func [pubkey [binary!] return: [binary!]
		/local hash
	][
		hash: pubkey-to-hash pubkey
		insert hash #{0014}
		hash
	]
]

]
