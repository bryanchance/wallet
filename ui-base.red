Red [
	Title:	"ui base"
	Author: "bitbegin"
	File: 	%ui-base.red
	Tabs: 	4
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#do [_ui-base_red_: yes]
#if error? try [_config_red_] [#include %config.red]
#if error? try [_keys_red_] [#include %keys/keys.red]

ui-base: context [
	set 'process-events does [loop 10 [do-events/no-wait]]

	tx-error: none

	unlock-dev-dlg: layout [
		title "Unlock your key"
		text font-size 12 {Unlock your Ledger key, open the Ethereum app, ensure "Browser support" is "No".}
		return
		pad 262x10 button "OK" [unview]
	]

	tx-error-dlg: layout [
		title "Send Transaction Error"
		tx-error: area 400x200
	]

]
