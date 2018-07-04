Red []
#if error? try [_int256_red_] [#include %../libs/int256.red]
#if error? try [_eth-api_red_] [#include %../libs/eth-api.red]
#if error? try [_int-encode_red_] [#include %../libs/int-encode.red]


network: https://eth.red-lang.org/rinkeby
contract: "43df37f66b8b9fececcc3031c9c1d2511db17c42"
addr: "0x7FA316502FE2EE86675F37760918ED75D4CB491A"

print "get-balance"
balance: try [eth-api/get-balance network addr]
either not error? balance [
	print ["balance: " form-i256 balance 18 18]
][
	probe balance
]

print "get-balance-token"
balance: try [eth-api/get-balance-token network contract addr]
either not error? balance [
	print ["balance: " form-i256 balance 18 18]
][
	probe balance
]

print "get-nonce"
nonce: try [eth-api/get-nonce network addr]
either not error? nonce [
	print ["nonce: " nonce]
][
	probe nonce
]
