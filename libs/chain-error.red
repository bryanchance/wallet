Red [
	Title:	"chain error type define"
	Author: "bitbegin"
	File: 	%chain-error.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

chain-error: context [

	create: func [name id message nxt /local err][
		make map! reduce ['magic "chain-error" 'error reduce ['name name 'id id 'msg message 'next nxt]]
	]

	find-by-id: func [err name id /local cur item][
		cur: err
		forever [
			item: cur/error
			if all [item/name = name item/id = id][
				return cur
			]
			if none = cur: item/next [break]
		]
		none
	]

	find-by-msg: func [err message /local cur item][
		cur: err
		forever [
			item: cur/error
			case [
				any [
					map? item/msg
					series? item/msg
				][
					if find item/msg message [return cur]
				]
				true [
					if item/msg = message [return cur]
				]
			]
			if none = cur: item/next [break]
		]
		none
	]

	is-err?: func [err /local item][
		if not map? err [return false]
		if err/magic <> "chain-error" [return false]
		item: err/error
		if all [item item/name] [return true]
		false
	]
]


comment: {
err1: chain-error/create 'test1 1 'msg1 none
print chain-error/is-err? err1
err2: chain-error/create 'test2 2 'msg2 err1
print chain-error/is-err? err2
err3: chain-error/create 'test3 3 "this is msg3!" err2
print chain-error/is-err? err3
probe err3
probe chain-error/find-by-msg err3 "msg3"
probe chain-error/find-by-id err3 'test1 1
}

