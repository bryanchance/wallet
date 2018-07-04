Red []
#if error? try [_int256_red_] [#include %../libs/int256.red]
#if error? try [_btc-api_red_] [#include %../libs/btc-api.red]
#if error? try [_int-encode_red_] [#include %../libs/int-encode.red]

network: https://chain.api.btc.com/v3

print "get-balance"
balance: try [btc-api/get-balance network "15urYnyeJe3gwbGJ74wcX89Tz7ZtsFDVew"]
either not error? balance [
	either balance [
		print ["balance: " form-i256 balance 8 8]
	][
		print "no record"
	]
][
	probe balance
]

print "get-unspent"
utx: try [btc-api/get-unspent network "15urYnyeJe3gwbGJ74wcX89Tz7ZtsFDVew"]
either not error? utx [
	either utx [
		probe utx
	][
		print "no record"
	]
][
	probe utx
]

print "get-tx-info"
info: try [btc-api/get-tx-info network "0eab89a271380b09987bcee5258fca91f28df4dadcedf892658b9bc261050d96"]
either not error? info [
	either info [
		probe info
	][
		print "no record"
	]
][
	probe info
]

rawtx: {0100000003ea19d9e3e29de76557693058a7fa9a03d83f2a8a364b2b6b47c556721143dc5c000000006a4730440220373c9e932ab77d620d7d448e2a3519d1287568d90cd02d759ea6d767327eb74d02207bc5ca3c60e167a45ed4655ec0bd23035d0e9b879253be4bb233c00aa101dc34012103efff984b25f091b57a205b158732f903d55395684931d26fdeaa1ce7bcb70b59ffffffff199322035d450b1772ee4809f44109479908122ba2b4a7ad6aa881c878c3c5ca010000006a473044022077ff6b29f81fb7c1488e70dfd8ef62c3a3ca2480def81063e2110db147434e090220439c0119560074a9bf06f5121e8f162455dd35d35394d29ddbbf9ed8226845680121021f518f74a076d2c5ef820770e28b9dd9d519b1ce233afd19ab1e99d020ed7d80ffffffff36f7775578a8e70bae6367e05c8c043b0e9792d0eeab2fd5b639d712745276de000000006a473044022019df54c86db21ecac05922fed9b89ba12d15cdc8772c408fd1640c57319947b102204186eec046e34df0e2419d3b2a37581937c7fda871ba51b258b619c585c8771b0121035ba00478908b562a53f6f43f8732d213e0c3c39905ebd1442dd01446c16621c5ffffffff0169abbb01000000001976a914a2c7d776f1dce27389225af277c0ba3625e81e0088ac00000000}

print "publish-tx"
res: try [btc-api/publish-tx network rawtx]
probe res

print "decode-tx"
res: try [btc-api/decode-tx network rawtx]
probe res

