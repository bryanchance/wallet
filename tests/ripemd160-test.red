Red []
#include %../../red/quick-test/quick-test.red
#include %../libs/ripemd160.red

~~~start-file~~~ "ripemd160 - test"

===start-group=== "ripemd160"
	data: ""
	expected: #{9C1185A5C5E9FC54612808977EE8F548B2258D31}
	--test-- "RIPEMD160_empty" --assert expected = ripemd160 data
	
	data: "The quick brown fox jumps over the lazy dog"
	expected: #{37f332f68db77bd9d7edd4969571ad671cf9dd3b}
	--test-- "RIPEMD160_quick" --assert expected = ripemd160 data
	
	data: "123456789"
	expected: #{d3d0379126c1e5e0ba70ad6e5e53ff6aeab9f4fa}
	--test-- "RIPEMD160_1-9" --assert expected = ripemd160 data
	
	data: "0123456789"
	expected: #{a1a922b488e74b095c32dd2eb0170654944d1225}
	--test-- "RIPEMD160_0-9" --assert expected = ripemd160 data

	data: {**Red** is a new programming language strongly inspired by [Rebol](http://rebol.com), but with a broader field of usage thanks to its native-code compiler, from system programming to high-level scripting, while providing modern support for concurrency and multi-core CPUs.}
	expected: #{f1259195ad4e58e154ffa9988dee6a88bcee5823}
	--test-- "RIPEMD160_long" --assert expected = ripemd160 data

===end-group===

~~~end-file~~~
