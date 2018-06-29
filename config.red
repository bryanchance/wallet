Red [
	Title:	"wallet config"
	Author: "bitbegin"
	File: 	%config.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

token-config: context [

	;-- m / purpose' / coin_type' / account' / change / address_index
	default-purpose: 80000000h + 44
	segwit-purpose: 80000000h + 49
	btc-coin: 80000000h + 0
	btc-test-coin: 80000000h + 1
	eth-coin: 80000000h + 60
	default-account: 80000000h + 0
	default-change: 0

	token-table: compose/deep [
		;token name
		"ETH" [
			['net-name "mainnet"	'network https://eth.red-lang.org/mainnet		'explorer https://etherscan.io/tx/				'path [(default-purpose) (eth-coin) (default-account) (default-change)] 'chain-id 1]
			['net-name "Rinkeby"	'network https://eth.red-lang.org/rinkeby		'explorer https://rinkeby.etherscan.io/tx/		'path [(default-purpose) (eth-coin) (default-account) (default-change)] 'chain-id 4]
			['net-name "Kovan"		'network https://eth.red-lang.org/kovan			'explorer https://kovan.etherscan.io/tx/		'path [(default-purpose) (eth-coin) (default-account) (default-change)] 'chain-id 42]
			['net-name "Ropsten"	'network https://eth.red-lang.org/ropsten		'explorer https://ropsten.etherscan.io/tx/		'path [(default-purpose) (eth-coin) (default-account) (default-change)] 'chain-id 3]
		]
		"RED" [
			['net-name "mainnet"	'network https://eth.red-lang.org/mainnet		'explorer https://etherscan.io/tx/				'path [(default-purpose) (eth-coin) (default-account) (default-change)] 'chain-id 1 'contract "76960Dccd5a1fe799F7c29bE9F19ceB4627aEb2f"]
			['net-name "Rinkeby"	'network https://eth.red-lang.org/rinkeby		'explorer https://rinkeby.etherscan.io/tx/		'path [(default-purpose) (eth-coin) (default-account) (default-change)] 'chain-id 4 'contract "43df37f66b8b9fececcc3031c9c1d2511db17c42"]
		]
		"BTC" [
			['net-name "BTC.COM"	'network https://chain.api.btc.com/v3			'explorer https://blockchain.info/tx/			'path [(segwit-purpose) (btc-coin) (default-account) (default-change)]]
			['net-name "Testnet3"	'network https://tchain.api.btc.com/v3			'explorer https://testnet.blockchain.info/tx/	'path [(segwit-purpose) (btc-test-coin) (default-account) (default-change)] 'unit-name "TEST"]
		]
		"BTC-old" [
			['net-name "BTC.COM"	'network https://chain.api.btc.com/v3			'explorer https://blockchain.info/tx/			'path [(default-purpose) (btc-coin) (default-account) (default-change)] 'unit-name "BTC"]
			['net-name "Testnet3"	'network https://tchain.api.btc.com/v3			'explorer https://testnet.blockchain.info/tx/	'path [(default-purpose) (btc-test-coin) (default-account) (default-change)] 'unit-name "TEST"]
		]
	]

	_net-names: []
	_networks: []
	_explorers: []
	
	react: make reactor! [
		token-names: extract token-table 2
		;- base item
		token-selected: 1
		net-selected: 1
		;- react item
		;- react for token-selected
		token-name: is [pick token-names token-selected]
		token-block: is [select token-table token-name]
		net-count: is [length? token-block]
		net-names: is [
			clear _net-names
			foreach net-blk token-block [
				append _net-names net-blk/net-name
			]
			_net-names
		]
		networks: is [
			clear _networks
			foreach net-blk token-block [
				append _networks net-blk/network
			]
			_networks
		]
		explorers: is [
			clear _explorers
			foreach net-blk token-block [
				append _explorers net-blk/explorer
			]
			_explorers
		]
		;- react for net-selected & token-selected
		net-block: is [pick token-block net-selected]
		net-name: is [either net-block [net-block/net-name][none]]
		network: is [either net-block [net-block/network][none]]
		explorer: is [either net-block [net-block/explorer][none]]
		path: is [either net-block [net-block/path][none]]
		unit-name: is [
			either net-block [
				either name: net-block/unit-name [name][token-name]
			][none]
		]
		contract: is [either net-block [net-block/contract][none]]
		chain-id: is [either net-block [net-block/chain-id][none]]
	]

	react/token-selected: 3
	react/net-selected: 2
]
