" Vim syntax plugin.
" Language:	LOTR - Lord of the Regs
" Maintainer:	Barry Arthur <barry.arthur@gmail.com>
" Version:	0.1
" Description:	Persistent view of Vim :registers
" Last Change:	2014-12-26
" License:	Vim License (see :help license)
" Location:	syntax/lotr.vim
" Website:	https://github.com/dahu/lotr
"
" See lotr.txt for help. This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help lotr

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

syn match lotrRegSpecial  "^[-"*+/]"
syn match lotrRegNumbered "^[0-9]"
syn match lotrRegLettered "^[a-z]"
syn match lotrYankStacked "^ [0-9]\|^[1-9][0-9]\+"
syn match lotrNewline     "\^J"

hi def link lotrRegSpecial	Constant
hi def link lotrRegNumbered	Special
hi def link lotrRegLettered	Identifier
hi def link lotrYankStacked	Function
hi def link lotrNewline		NonText

let b:current_syntax = "lotr"

let &cpo = s:save_cpo
unlet s:save_cpo

" Template From: https://github.com/dahu/Area-41/
" vim: set sw=2 sts=2 et fdm=marker:
