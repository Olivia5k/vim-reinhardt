if exists('g:loaded_reinhardt') || &cp || v:version < 700
  finish
endif
let g:loaded_reinhardt = 1

function! s:error(str)
  echohl ErrorMsg
  echomsg a:str
  echohl None
  let v:errmsg = a:str
endfunction

function! s:autoload()
  if !exists("g:autoloaded_reinhardt") && v:version >= 700
    runtime! autoload/reinhardt.vim
  endif
  if exists("g:autoloaded_reinhardt")
    return 1
  endif
  if !exists("g:reinhardt_no_autoload_warning")
    let g:reinhardt_no_autoload_warning = 1
    if v:version >= 700
      call s:error("Disabling reinhardt: autoload/reinhardt.vim is missing")
    else
      call s:error("Disabling reinhardt: Vim version 7 or higher required")
    endif
  endif
  return ""
endfunction

function! s:Detect(filename)
  if exists('b:reinhardt_root') || exists('b:reinhardt_app')
    return BufInit()
  endif

  let fn = substitute(fnamemodify(a:filename, ":p"), '\c^file://', '', '')
  let ofn = ""

  while fn != ofn
    let ofn = fn
    let fn = fnamemodify(fn, ":h")

    if filereadable(fn . '/models.py')
      let b:reinhardt_app = fn
    elseif filereadable(fn . '/manage.py')
      let b:reinhardt_root = fn
      break
    endif
  endwhile

  if exists('b:reinhardt_root') || exists('b:reinhardt_app')
    call s:autoload()
    call BufInit()
  endif
endfunction

augroup reinhardtDetect
  autocmd!
  autocmd BufNewFile,BufRead * call s:Detect(expand("<afile>:p"))
augroup END

" vim:set sw=2 sts=2:
