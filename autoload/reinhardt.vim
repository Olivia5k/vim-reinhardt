" autoload/reinhardt.vim
" Author:       Lowe Thiderman <lowe.thiderman@gmail.com>

" Install this file as autoload/rails.vim.

if exists('g:autoloaded_reinhardt') || &cp
  finish
endif
let g:autoloaded_reinhardt = '0.1'

let s:cpo_save = &cpo
set cpo&vim

" Template finders {{{1

function! s:find_template(str)
  for app in values(s:apps)
    let fn = app . '/templates/' . a:str
    if filereadable(fn)
      return fn
    endif
  endfor

  " Create a new in the current app; with directory creation
  " return s:new_template(a:str)
  echo "No template found"
endfunction

function! s:FindDefinition()
  " The default functionality of gf
  if filereadable(expand("<cfile>"))
    return expand("<cfile>")
  endif

  let str = s:cursorstr()
  let res = s:find_template(str)
  if res != ""|edit `=res`|endif
endfunction

" }}}
" Utilities {{{1

function! s:cursorstr()
  " Returns the string under the cursor
  let q = "[\"']"
  let res = matchlist(getline('.'), q.'\(\S*\)'.q)
  if len(res) == 0
    return ""
  endif
  return res[1]
endfunction

function! s:get_current_app()
  let fn = fnamemodify(bufname('%'), ":p")
  while fn != g:reinhardt_root
    let fn = fnamemodify(fn, ":h")
    if s:is_app(fn)
      break
    endif
  endwhile

  if fn != g:reinhardt_root
    return fn
  endif
  return ""
endfunction

function! s:is_app(dir)
  return filereadable(a:dir . '/models.py')  " Is this enough?
endfunction

function! s:error(str)
  echohl ErrorMsg
  echomsg "Error: ".a:str
  echohl None
  let v:errmsg = a:str
endfunction

function! s:get_current_lang()
  if exists('g:reinhardt_lang')
    return g:reinhardt_lang
  endif

  let app = s:get_current_app()

  if app == "" || isdirectory(app.'/locale')
    " No locale has been created yet, or we are not in an app. Default to english.
    return 'en'
  endif

  let langs = split(globpath(app.'/locale', '*'), '\n')

  if len(langs) == 0 || index('en', langs) >= 0
    " There are english files, or no files at all. Default to english.
    return 'en'
  else
    " There are languages, but none of them are english. Pick the first one.
    return langs[0]
  endif
endfunction

function! s:add_ft(ft, append)
  " Add a filetype. Make sure to retain any other filetypes that have been set
  let fts = [&ft]
  if stridx(&ft, '.') != -1
    let fts = split(&ft, '.')
  endif

  if index(fts, a:ft) == -1
    if a:append
      let fts = add(fts, a:ft)
    else
      let fts = insert(fts, a:ft)
    endif
    exec "set ft=". join(fts, '.')
  endif
endfunction

" }}}
" Mappings {{{1

function! s:altmap(name, key)
  let k = g:reinhardt_mapkey
  exe 'nmap '.k.a:key.' :R'.a:name.'<cr>'
  exe 'nmap '.k.toupper(a:key).' :R'.a:name.' '
endfunction

function! s:BufMappings()
  nnoremap <buffer> <silent> <Plug>ReinhardtFind :<C-U>call <SID>FindDefinition()<CR>

  if !hasmapto("<Plug>ReinhardtFind")
    nmap <buffer> gf <Plug>ReinhardtFind
  endif

  command! -buffer -bar -nargs=? Rfind :call s:FindDefinition(<f-args>)

  if exists('g:reinhardt_mapkey')
    let k = g:reinhardt_mapkey
    exe "nmap ".k."<space> :Rswitch "

    call s:altmap('admin', 'a')
    call s:altmap('fixture', 'x')
    call s:altmap('form', 'f')
    call s:altmap('init', 'i')
    call s:altmap('locale', 'l')
    call s:altmap('manage', 'n')
    call s:altmap('middle', 'd')
    call s:altmap('model', 'm')
    call s:altmap('template', 'e')
    call s:altmap('test', 't')
    call s:altmap('url', 'u')
    call s:altmap('view', 'v')
  endif
endfunction

" }}}
" Alternating {{{1

function! s:Edit(name, ...) abort
  let fn = ''
  if a:0
    let fn = s:switch_file(a:name, a:1)
  else
    let fn = s:switch_file(a:name)
  endif

  if fn == ""
    call s:error('No file found for ' . a:name)
    return
  endif

  let fn = s:get_current_app(). '/' . fn
  edit `=fn`
endfunction

function! s:switch_app(name)
  if !has_key(s:apps, a:name)
    call s:error(a:name . " - No such app.")
  endif

  let app = s:apps[a:name]
  let cur = s:get_current_app()
  let fn = "/models.py"
  let msg = ""

  if cur != ""
    let nfn = substitute(fnamemodify(bufname('%'), ':p'), cur, "", "")
    if filereadable(app.nfn)
      let fn = nfn
    else
      let msg = nfn . " not found in ".fnamemodify(app, ':t').". Going to models.py."
    endif
  else
    let msg = "Currently not in an app. Going to models.py."
  endif

  silent edit `=app.fn`

  if msg != ""
    echo msg
  endif
endfunction

function! s:switch_file(kind, ...)
  let cur = s:get_current_app()
  if cur == ""
    return ""
  endif

  if a:kind == "locale"
    return 'locale/'.(a:0 ? a:1 : s:get_current_lang()).'/LC_MESSAGES/django.po'

  elseif a:kind == "fixture"
    if a:0
      return 'fixtures/' . a:1
    endif

    let fix = split(globpath(cur . '/fixtures', '*'), '\n')
    if len(fix) == 0  " No fixtures. Go default.
      return 'fixtures/initial_data.json'
    elseif len(fix) == 1  " One fixture, go to it directly
      return 'fixtures/' . fnamemodify(fix[0], ':t')
    else  " Many fixtures, return the dir so the user can choose
      return 'fixtures/'
    endif

  elseif a:kind == "manage"
    if a:0
      return 'management/commands/' . a:1 . '.py'
    endif

    let com = split(globpath(cur . '/management/commands', '*'), '\n')
    let com = filter(com, 'v:val != "__init__.py"')

    if len(com) == 1  " One command, go to it directly
      return 'management/commands/' . fnamemodify(com[0], ':t')
    else  " Many commands, return the dir so the user can choose
      " s:setup_management()
      return 'management/commands/'
    endif

  elseif a:kind == "init"
    return '__init__.py'

  else
    " For simplicity, try plural and if it does not exist, return singular
    if filereadable(cur . '/'. a:kind . "s.py")
      return a:kind . "s.py"
    else
      return a:kind .'.py'
    endif
  endif
endfunction

command! -nargs=1 -complete=customlist,s:Appcpl  Rswitch   :call s:switch_app(<f-args>)
command! -nargs=? -complete=customlist,s:Langcpl Rlocale   :call s:Edit('locale', <f-args>)
command! -nargs=? -complete=customlist,s:Fixcpl  Rfixture  :call s:Edit('fixture', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Radmin    :call s:Edit('admin', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rform     :call s:Edit('form', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rinit     :call s:Edit('init', <f-args>)
command! -nargs=? -complete=customlist,s:Mgmcpl  Rmanage   :call s:Edit('manage', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rmodel    :call s:Edit('model', <f-args>)
command! -nargs=? -complete=customlist,s:Tmpcpl  Rtemplate :call s:Edit('template', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rtest     :call s:Edit('test', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rurl      :call s:Edit('url', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rview     :call s:Edit('view', <f-args>)
command! -nargs=? -complete=customlist,s:Appcpl  Rmiddle   :call s:Edit('middleware', <f-args>)

" }}}
" Completion {{{1

function! s:cpl_dir(path, mod, A, ...)
  " Get files for completion functions
  let app = s:get_current_app()
  let path = app.a:path

  if app == "" || !isdirectory(path)
    return []
  endif

  let f = 'v:val =~# "^".a:A'
  if a:0 " If needed, make a loop that goes through all of them?
    let f = f . ' && ' . a:1
  endif

  let l = map(split(globpath(path, '*'), '\n'), "fnamemodify(v:val, '".a:mod."')")
  return filter(l, f)

endfunction

function! s:Appcpl(A,P,L)
  " Complete all apps except the current one
  let appname = fnamemodify(s:get_current_app(), ":t")
  return sort(filter(keys(s:apps), 'v:val =~# "^".a:A && v:val != appname'))
endfunction

function! s:Langcpl(A,P,L)
  return s:cpl_dir('/locale', ':t', a:A)
endfunction

function! s:Fixcpl(A,P,L)
  return s:cpl_dir('/fixtures', ':t', a:A)
endfunction

function! s:Tmpcpl(A,P,L)
  return s:cpl_dir('/templates', ':t', a:A)
endfunction

function! s:Mgmcpl(A,P,L)
  return s:cpl_dir('/management/commands/', ':t:r', a:A, 'v:val != "__init__"')
endfunction

" }}}
" Initialization {{{1

function! s:find_apps(...)
  " Recursively test for Django apps, default to the app root
  let path = a:0 ? a:1 : g:reinhardt_root
  for dir in filter(split(globpath(path, '*'), '\n'), 'isdirectory(v:val)')
    if filereadable(dir . '/__init__.py') " Skip anything non-python
      if s:is_app(dir)
        let s:apps[fnamemodify(dir, ":t")] = dir
      else
        call s:find_apps(dir)
      endif
    endif
  endfor
endfunction

function! BufInit()
  call s:find_apps()
  call s:BufMappings()

  if &ft =~ 'python'
    call s:add_ft('django', 1)
  elseif &ft =~ 'x\?html\?'
    call s:add_ft('htmldjango', 0)
  endif
endfunction

exe 'map <Plug>xsid <SID>|let s:sid=matchstr(maparg("<Plug>xsid"), "\\d\\+_")|unmap <Plug>xsid'
let s:file = expand('<sfile>:p')

if !exists('s:apps')
  let s:apps = {}
endif

" }}}

let &cpo = s:cpo_save
" vim:set sw=2 sts=2:
