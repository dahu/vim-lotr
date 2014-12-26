let s:core_regs = ['*', '+', '-', '"']

function! Update()
  let s:regs = {}
  for reg in extend(extend(range(10), s:core_regs), map(range(26), 'nr2char(char2nr("a") + v:val)'))
    call extend(s:regs, {reg : getreg(reg)})
  endfor

endfunction

function! List()
  for reg in extend(range(10), s:core_regs)
    echon reg . ' ' . substitute(s:regs[reg], '\n', '^J', 'g') . "\n"
  endfor
  for regn in range(26)
    let reg = nr2char(char2nr('a') + regn)
    if (has_key(s:regs, reg)) && (s:regs[reg] != '')
      echon reg . ' ' . substitute(s:regs[reg], '\n', '^J', 'g') . "\n"
    endif
  endfor
endfunction

call Update()

" au CursorHold  * call Update()
" au CursorMoved * call Update()
