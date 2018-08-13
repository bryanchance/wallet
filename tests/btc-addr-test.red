Red []
#include %../../red/quick-test/quick-test.red
#include %../libs/btc-addr.red

~~~start-file~~~ "btc-addr - test"

===start-group=== "btc-addr"
	pub-key: #{04844E040EB155A0CF9466A195FC1349E57AD605EC7F890361251C4C9FCC71553D18EBF1D8AC33EFDBFA205215A1097F0A13D18D2CEC16883816BCECD6CD79E0B5}
	xkey: head insert copy/part skip pub-key 1 32 3
	expected: "2MxBBawLwEFGqy3nUzN8YQbdu7UEnEKcGrZ"
	--test-- "btc-addr ledger xkey first"
		--assert expected = btc-addr/pubkey-to-segwit-addr xkey 'TEST-P2SH

	pub-key: #{0443183DE41837D5051817FCF85347E1B497DD607E19D0CD50B2E505CB109A211C69B9D4A9F1BF7CC4C7DE35FBB5286D0CAD6E44428EFBFD6E9C77C2A06AC61BC2}
	xkey: head insert copy/part skip pub-key 1 32 2
	expected: "36z4LfwjRS8sBYhoKyPnigWbhKuUdZZUC8"
	--test-- "btc-addr ledger ykey first"
		--assert expected = btc-addr/pubkey-to-segwit-addr xkey 'P2SH

	xkey: #{03a1af804ac108a8a51782198c2d034b28bf90c8803f5a53f76276fa69a4eae77f}
	expected: "2Mww8dCYPUpKHofjgcXcBCEGmniw9CoaiD2"
	--test-- "btc-addr xkey"
		--assert expected = btc-addr/pubkey-to-segwit-addr xkey 'TEST-P2SH

	ykey: #{02c772a1d29bb217c99fae64e59115b35acbeb93abe2278da615140ad41ac74dd9}
	expected: "2N9SkPnt8pDee5beS545WbmR2MgBnxppHEb"
	--test-- "btc-addr ykey"
		--assert expected = btc-addr/pubkey-to-segwit-addr ykey 'TEST-P2SH

===end-group===

~~~end-file~~~
