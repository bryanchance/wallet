Red [
	Title:	"chain error type define"
	Author: "bitbegin"
	File: 	%chain-error.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

chain-error: context [

	new: func [name id message nxt /local err][
		make map! reduce ['magic "chain-error" 'error reduce ['name name 'id id 'msg message 'next nxt]]
	]

	get-root: func [err /local cur item][
		cur: err
		forever [
			item: cur/error
			unless item/next [return cur]
			cur: item/next
		]
		none
	]

	find-by-id: func [err name id /local cur item][
		cur: err
		forever [
			item: cur/error
			if all [item/name = name item/id = id][
				return cur
			]
			unless cur: item/next [break]
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
			unless cur: item/next [break]
		]
		none
	]

	error?: func [err /local item][
		unless map? err [return false]
		if err/magic <> "chain-error" [return false]
		item: err/error
		if all [item item/name] [return true]
		false
	]

	form-err: func [err /local error][
		error: err/error
		rejoin [to string! error/name ": <id: " form error/id "><msg: " form error/msg ">"]
	]
]


comment: {
err1: chain-error/new 'test1 1 'msg1 none
print chain-error/error? err1
err2: chain-error/new 'test2 2 'msg2 err1
print chain-error/error? err2
err3: chain-error/new 'test3 3 "this is msg3!" err2
print chain-error/error? err3
chain-error/form-err err1
chain-error/form-err err2
chain-error/form-err err3
probe chain-error/find-by-msg err3 "msg3"
probe chain-error/find-by-id err3 'test1 1

chain-error/form-err chain-error/get-root err1
chain-error/form-err chain-error/get-root err2
chain-error/form-err chain-error/get-root err3
}

