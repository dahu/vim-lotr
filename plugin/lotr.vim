"" ============================================================================
" File:        lotr-view.vim
" Description: A persistent view of :registers in Vim
" Authors:     Barry Arthur <barry.arthur@gmail.com>
" Licence:     Vim licence
" Website:     http://dahu.github.com/vim-lotr/
" Version:     0.1
" Note:        This plugin was heavily inspired by the 'Tagbar' plugin by
"              Jan Larres and uses great gobs of code from it.
"
" Original taglist copyright notice:
"              Permission is hereby granted to use and distribute this code,
"              with or without modifications, provided that this copyright
"              notice is copied with it. Like anything else that's free,
"              taglist.vim is provided *as is* and comes with no warranty of
"              any kind, either expressed or implied. In no event will the
"              copyright holder be liable for any damamges resulting from the
"              use of this software.
" ============================================================================

if &cp || exists('g:loaded_lotr')
  finish
endif

" Initialization {{{1

" Basic init {{{2

" if v:version < 704
"       \ || v:version == 704 && !has('patch392')
"   echomsg 'LOTR: Vim version is too old, LOTR requires at least 7.4, patch 392'
"   finish
" endif
if v:version < 702
  echomsg 'LOTR: Vim version is too old, LOTR requires at least 7.3'
  finish
endif

redir => s:ftype_out
silent filetype
redir END
if s:ftype_out !~# 'detection:ON'
  echomsg 'LOTR: Filetype detection is turned off, skipping plugin'
  unlet s:ftype_out
  finish
endif
unlet s:ftype_out

let g:loaded_lotr = 1

if !exists('g:lotr_left')
  let g:lotr_left = 0
endif

if !exists('g:lotr_position')
  let g:lotr_position = g:lotr_left ? 'left' : 'right'
endif

if !exists('g:lotr_width')
  let g:lotr_width = 25
endif

if !exists('g:lotr_expand')
  let g:lotr_expand = 0
endif

let s:autocommands_done        = 0
let s:source_autocommands_done = 0
let s:window_expanded          = 0

" Registers {{{2
function! LOTR_Regs()
  let core_regs = ['"', '-', '*', '+']
  let regs = {}
  let reglist = []

  for reg in extend(extend(range(10), core_regs), map(range(26), 'nr2char(char2nr("a") + v:val)'))
    call extend(regs, {reg : getreg(reg)})
  endfor

  for reg in core_regs
    call add(reglist, reg . ' ' . substitute(regs[reg], '\n', '^J', 'g'))
  endfor

  call add(reglist, '')

  for reg in range(10)
    call add(reglist, reg . ' ' . substitute(regs[reg], '\n', '^J', 'g'))
  endfor

  call add(reglist, '')

  for regn in range(26)
    let reg = nr2char(char2nr('a') + regn)
    if (has_key(regs, reg)) && (regs[reg] != '')
      call add(reglist, reg . ' ' . substitute(regs[reg], '\n', '^J', 'g'))
    endif
  endfor

  return reglist
endfunction

function! s:CreateAutocommands() "{{{2
  augroup LOTR_AutoCmds
    autocmd!
    autocmd BufEnter               __LOTR__  nested call s:QuitIfOnlyWindow()
    autocmd BufUnload              __LOTR__         call s:CleanUp()
    autocmd CursorHold,CursorMoved *                call s:AutoUpdate()
  augroup END

  let s:autocommands_done = 1
endfunction

function! s:MapKeys() "{{{2
  nnoremap <script> <silent> <buffer> <CR>    :wincmd p<cr>
  nnoremap <script> <silent> <buffer> <space> :call <SID>ZoomWindow()<CR>
  nnoremap <script> <silent> <buffer> q       :call <SID>CloseWindow()<CR>
endfunction

" Window management {{{1
" Window management code shamelessly stolen from the Tagbar plugin:
" http://www.vim.org/scripts/script.php?script_id=3465

function! s:ToggleWindow() "{{{2
  let lotr_winnr = bufwinnr("__LOTR__")
  if lotr_winnr != -1
    call s:CloseWindow()
  else
    call s:OpenWindow()
  endif
endfunction

function! s:OpenWindow() "{{{2
  " do nothing if the LOTR window is already open
  let lotr_winnr = bufwinnr('__LOTR__')
  if lotr_winnr != -1
    return
  endif
  if !s:IsWindowValidToSplit()
    return
  endif
  let s:lotr_regs = LOTR_Regs()

  " Expand the Vim window to accomodate for the LOTR window if requested
  if g:lotr_expand && !s:window_expanded && has('gui_running')
    let &columns += g:lotr_width + 1
    let s:window_expanded = 1
  endif

  let openpos = {
        \ 'top'    : 'topleft',  'left'  : 'topleft vertical',
        \ 'bottom' : 'botright', 'right' : 'botright vertical'}
        \[g:lotr_position] . ' '
  exe 'silent keepalt ' . openpos . g:lotr_width . ' split ' . '__LOTR__'
  call s:InitWindow()
  wincmd p
endfunction

function! s:InitWindow() "{{{2
  setlocal noreadonly " in case the "view" mode is used
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal filetype=lotr
  setlocal nolist
  setlocal nonumber
  setlocal nowrap
  setlocal winfixwidth
  setlocal textwidth=0

  if exists('+relativenumber')
    setlocal norelativenumber
  endif

  setlocal nofoldenable
  setlocal foldcolumn=0
  " Reset fold settings in case a plugin set them globally to something
  " expensive. Apparently 'foldexpr' gets executed even if 'foldenable' is
  " off, and then for every appended line (like with :put).
  setlocal foldmethod&
  setlocal foldexpr&

  let s:is_maximized = 0

  let cpoptions_save = &cpoptions
  set cpoptions&vim

  if !hasmapto('CloseWindow', 'n')
    call s:MapKeys()
  endif

  if !s:autocommands_done
    call s:CreateAutocommands()
  endif

  setlocal statusline=\ [LOTR]

  call s:RenderContent()

  let &cpoptions = cpoptions_save
endfunction

function! s:CloseWindow() "{{{2
  let lotr_winnr = bufwinnr('__LOTR__')
  if lotr_winnr == -1
    return
  endif

  let lotr_bufnr = winbufnr(lotr_winnr)

  if winnr() == lotr_winnr
    if winbufnr(2) != -1
      " Other windows are open, only close the LOTR one
      close
    endif
  else
    " Go to the LOTR window, close it and then come back to the
    " original window
    let curbufnr = bufnr('%')
    execute lotr_winnr . 'wincmd w'
    close
    " Need to jump back to the original window only if we are not
    " already in that window
    let winnum = bufwinnr(curbufnr)
    if winnr() != winnum
      exe winnum . 'wincmd w'
    endif
  endif

  " If the Vim window has been expanded, and LOTR is not open in any other
  " tabpages, shrink the window again
  if s:window_expanded
    let tablist = []
    for i in range(tabpagenr('$'))
      call extend(tablist, tabpagebuflist(i + 1))
    endfor

    if index(tablist, lotr_bufnr) == -1
      let &columns -= g:lotr_width + 1
      let s:window_expanded = 0
    endif
  endif
endfunction

function! s:ZoomWindow() "{{{2
  if s:is_maximized
    execute 'vert resize ' . g:lotr_width
    let s:is_maximized = 0
  else
    vert resize
    let s:is_maximized = 1
  endif
endfunction

" Display {{{1
function! s:RenderContent() "{{{2
  " only update the LOTR window if we're in normal mode
  if mode(1) != 'n'
    return
  endif
  if !s:IsWindowValidToSplit()
    return
  endif
  let lotr_winnr = bufwinnr('__LOTR__')

  if &filetype == 'lotr'
    let in_lotr = 1
  else
    let in_lotr = 0
    let s:lotr_regs = LOTR_Regs()
    let prevwinnr = winnr()
    execute lotr_winnr . 'wincmd w'
  endif

  let lazyredraw_save = &lazyredraw
  set lazyredraw
  let eventignore_save = &eventignore
  set eventignore=all

  setlocal modifiable

  silent %delete _

  call s:PrintRegs()

  setlocal nomodifiable

  let &lazyredraw  = lazyredraw_save
  let &eventignore = eventignore_save

  if !in_lotr
    execute prevwinnr . 'wincmd w'
  endif
endfunction

function! s:PrintRegs() "{{{2
  call setline(1, s:lotr_regs)
endfunction

" User Actions {{{1

" Helper Functions {{{1

function! s:CleanUp() "{{{2
  silent autocmd! LOTR_AutoCmds
  unlet s:is_maximized
  " unlet s:compare_typeinfo
endfunction

function! s:QuitIfOnlyWindow() "{{{2
  " Before quitting Vim, delete the LOTR buffer so that
  " the '0 mark is correctly set to the previous buffer.
  if winbufnr(2) == -1
    " Check if there is more than one tab page
    if tabpagenr('$') == 1
      bdelete
      quit
    else
      close
    endif
  endif
endfunction

function! s:AutoUpdate() " {{{2
  " Don't do anything if LOTR is not open or if we're in the LOTR window
  let lotr_winnr = bufwinnr('__LOTR__')
  if lotr_winnr == -1
    return
  endif
  call s:RenderContent()
endfunction
function! s:IsWindowValidToSplit() " {{{2
  " Error if we try to split command window
  " Returns 1 if we should proceed to open LOTR window.
  " TODO: if we are in the command or some other invalid window,
  " first move to a 'good' window for the splitting?
  if exists("*getcmdwintype") && getcmdwintype() != ""
    echomsg "Cannot open LOTR from the command window"
    return 0
  elseif bufname('%') == "[Command Line]"
    echomsg "Cannot open LOTR from the command window"
    return 0
  endif
  return 1
endfunction

" Maps {{{1
nnoremap <plug>LOTRToggle :LOTRToggle<cr>

if ! hasmapto('<plug>LOTRToggle')
  nmap <leader>cr <plug>LOTRToggle
endif

" Commands {{{1
command! -bar -nargs=0 LOTRToggle        call s:ToggleWindow()
command! -bar -nargs=0 LOTROpen          call s:OpenWindow()
command! -bar -nargs=0 LOTRClose         call s:CloseWindow()

" Modeline {{{1
" vim: ts=8 sw=2 sts=2 et foldenable foldmethod=marker foldcolumn=1
