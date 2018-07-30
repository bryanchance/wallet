Red [
	Title:	"ui base"
	Author: "bitbegin"
	File: 	%ui-base.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#if error? try [_ui-base_red_][
#do [_ui-base_red_: yes]
#include %config.red
#include %keys/keys.red

ui-base: context [
	set 'process-events does [loop 10 [do-events/no-wait]]

	tx-error: none

	tx-error-dlg: layout [
		title "Send Transaction Error"
		tx-error: area 400x200
	]

	show-error-dlg: func [e [error!]][
		tx-error/text: form e
		view/flags tx-error-dlg 'modal
	]
]

]
