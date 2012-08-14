" autoload/reinhardt.vim
" Author:       Lowe Thiderman <lowe.thiderman@gmail.com>

" Install this file as autoload/reinhardt.vim.

if exists('g:autoloaded_reinhardt') || &cp
  finish
endif
let g:autoloaded_reinhardt = '0.1'

let s:cpo_save = &cpo
set cpo&vim

" Template finders {{{1

function! s:find_template(str)
  for app in values(s:apps)
    let fn = s:join(app, 'templates', a:str)
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
    return s:relpath(fn)
  endif
  return ""
endfunction

function! s:relpath(path, ...)
  let path = fnamemodify(a:path, ':p')

  if a:0
    " Extra argument. Make result relative to that path.
    let rel = fnamemodify(a:1, ':p')
    return substitute(path, rel, '', '')  " Make it relative!
  else
    let rel = getcwd() . s:slash
    let rel = substitute(path, rel, '', '')  " Make it relative!

    " If getcwd() is the same as the target, the string would be empty. This
    " would be a no-go for s:get_current_app and the like, who returns empty
    " strings on errors. This is probably the best workaround.
    return rel == '' ? './' : rel
  endif
endfunction

function! s:is_app(dir)
  return filereadable(s:join(a:dir, 'models.py'))  " Is this enough?
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

  let dir = s:join(app, 'locale')
  if app == "" || isdirectory(dir)
    " No locale has been created yet, or we are not in an app. Default to english.
    return 'en'
  endif

  let langs = split(globpath(dir, '*'), '\n')

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

function! s:default_file(app, path, ...)
  let files = split(globpath(s:join(a:app, a:path), '*'), '\n')
  let files = filter(files, 'v:val !~ "__init__.py$"')

  if len(files) == 0 && a:0 " No files. Go default if one is provided
    return s:join(a:path, a:1)
  elseif len(files) == 1  " One fixture, go to it directly
    return s:join(a:path, fnamemodify(files[0], ':t'))
  else  " Many files, return the dir so the user can choose
    return a:path
  endif
endfunction

function! s:join(...)
  " Join paths, just like os.path.join
  let ret = []
  for str in a:000  " The a: vars are not mutable. See E742.
    " Remove extra slashes
    let ret = add(ret, substitute(str, s:slash.'\+$', "", ""))
  endfor

  return join(ret, s:slash)
endfunction

" }}}
" Mappings {{{1

function! s:altmap(name, key)
  let k = g:reinhardt_mapkey
  exe 'nmap <buffer> <silent> '.k.a:key.' :R'.a:name.'<cr>'
  exe 'nmap <buffer> <silent> '.k.toupper(a:key).' :R'.a:name.' '
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
    call s:altmap('locale', 'l')
    call s:altmap('manage', 'n')
    call s:altmap('middle', 'd')
    call s:altmap('model', 'm')
    call s:altmap('static', 's')
    call s:altmap('template', 'e')
    call s:altmap('test', 't')
    call s:altmap('url', 'u')
    call s:altmap('util', 'i')
    call s:altmap('view', 'v')
  endif
endfunction

" }}}
" Alternating and navigation {{{1

function! s:Edit(name, cmd, ...) abort
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

  let fn = s:join(s:get_current_app(), fn)
  let cmd = 'edit'
  if a:cmd == "S"
    let cmd = "split"
  elseif a:cmd == "V"
    let cmd = "vsplit"
  elseif a:cmd == "T"
    let cmd = "tabedit"
  endif

  exe cmd fn
endfunction

function! s:switch_app(name)
  if !has_key(s:apps, a:name)
    call s:error(a:name . " - No such app.")
    return
  endif

  let app = s:apps[a:name]
  let cur = s:get_current_app()
  let fn = "models.py"
  let msg = ""

  if cur != ""
    let nfn = s:relpath(bufname('%'), cur)
    " let nfn = substitute(cf, cur . s:slash, "", "")
    if filereadable(s:join(app, nfn))
      let fn = nfn
    else
      let msg = nfn . " not found in ".a:name.". Going to models.py."
    endif
  else
    let msg = "Currently not in an app. Going to models.py."
  endif

  silent edit `=s:join(s:relpath(app), fn)`

  if msg != ""
    echo msg
  endif
endfunction

function! s:switch_file(kind, ...)
  let app = s:get_current_app()
  if app == ""
    return ""
  endif

  if a:kind == "locale"
    let lang = a:0 ? a:1 : s:get_current_lang()
    return s:join('locale', lang, 'LC_MESSAGES', 'django.po')

  elseif a:kind == "fixture"
    if a:0
      return s:join('fixtures', a:1)
    endif

    return s:default_file(app, 'fixtures', 'initital_data.json')

  elseif a:kind == "manage"
    let dir = s:join('management', 'commands')
    if a:0
      return s:join(dir, a:1 . '.py')
    endif

    return s:default_file(app, d)

  elseif a:kind == "template"
    if a:0
      return s:join('templates', a:1)
    endif

    return s:default_file(app, 'templates', 'base.html')

  elseif a:kind == "init"
    return '__init__.py'

  else
    " For simplicity, try plural and if it does not exist, return singular.
    " Also, try directories.
    if filereadable(s:join(app, a:kind . "s.py"))
      return a:kind . "s.py"
    elseif isdirectory(s:join(app, a:kind . "s"))
      return a:kind . "s"
    elseif isdirectory(s:join(app, a:kind))
      return a:kind
    else
      return a:kind . '.py'
    endif
  endif
endfunction

function! s:Cd(cmd, ...)
  let path = g:reinhardt_root
  if a:0
    if !has_key(s:apps, a:1)
      call s:error(a:1 . " - No such app.")
      return
    endif

    let path = s:apps[a:1]
    call s:switch_app(a:1)
  endif

  let path = s:relpath(path)

  " If the path is empty, we are already at the destination. An empty l?cd
  " would go to the users $HOME, which is not what we want.
  if path != ""
    exe a:cmd path
  endif
endfunction

function! s:addcmd(type, ...)
  let cpl = a:0 ? a:1 : 'App'
  let cmds = 'ESVT '
  let cmd = ''

  while cmds != ''
    let s = 'com! -nargs=? -complete=customlist,s:'.cpl.'cpl R'.cmd.a:type.' '
    let s = s . ':call s:Edit("'.a:type.'", "'.cmd.'", <f-args>)'
    exe s

    let cmd = strpart(cmds,0,1)
    let cmds = strpart(cmds,1)
  endwhile
endfunction

com! -nargs=1 -complete=customlist,s:Appcpl Rswitch :call s:switch_app(<f-args>)
com! -nargs=? -complete=customlist,s:Appcpl Rcd  :call s:Cd('cd', <f-args>)
com! -nargs=? -complete=customlist,s:Appcpl Rlcd :call s:Cd('lcd', <f-args>)

call s:addcmd('admin')
call s:addcmd('fixture', 'Fix')
call s:addcmd('form')
call s:addcmd('init')
call s:addcmd('locale', 'Lang')
call s:addcmd('manage', 'Mgm')
call s:addcmd('middle')
call s:addcmd('model')
call s:addcmd('static')
call s:addcmd('template', 'Tmp')
call s:addcmd('test')
call s:addcmd('url')
call s:addcmd('util')
call s:addcmd('view')
" }}}
" Completion {{{1

function! s:cpl_dir(path, glob, mod, A, ...)
  " Get files for completion functions
  let app = s:get_current_app()
  let path = s:join(app, a:path)

  if app == "" || !isdirectory(path)
    return []
  endif

  let f = 'v:val =~# "^".a:A'
  if a:0 " If needed, make a loop that goes through all of them?
    let f = f . ' && ' . a:1
  endif

  let l = split(globpath(path, a:glob), '\n')
  let l = filter(l, '!isdirectory(v:val)')  " TODO: Es broken
  let l = map(l, 'substitute(v:val, "'.path.s:slash.'", "", "")')
  if a:mod != ""
    let l = map(l, "fnamemodify(v:val, '".a:mod."')")
  endif
  return filter(l, f)
endfunction

function! s:Appcpl(A,P,L)
  " Complete all apps except the current one
  let appname = fnamemodify(s:get_current_app(), ":t")
  return sort(filter(keys(s:apps), 'v:val =~# "^".a:A && v:val != appname'))
endfunction

function! s:Langcpl(A,P,L)
  return s:cpl_dir('locale', '*', ':t', a:A)
endfunction

function! s:Fixcpl(A,P,L)
  return s:cpl_dir('fixtures', '*', ':t', a:A)
endfunction

function! s:Tmpcpl(A,P,L)
  return s:cpl_dir('templates', '**'.s:slash.'*', '', a:A)
endfunction

function! s:Mgmcpl(A,P,L)
  let dir = s:join('management', 'commands')
  return s:cpl_dir(dir, '*', ':t:r', a:A, 'v:val != "__init__"')
endfunction

" }}}
" Initialization {{{1

function! s:find_apps(...)
  " Recursively test for Django apps, default to the app root
  let path = a:0 ? a:1 : g:reinhardt_root
  for dir in filter(split(globpath(path, '*'), '\n'), 'isdirectory(v:val)')
    if filereadable(s:join(dir, '__init__.py')) " Skip anything non-python
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

if !exists('s:slash')
  " Windows compability, probably?
  let s:slash = has('win32') || has('win64') ? '\' : '/'
endif

" }}}

let &cpo = s:cpo_save
" vim:set sw=2 sts=2:
