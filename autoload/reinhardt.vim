" autoload/reinhardt.vim
" Author:       Lowe Thiderman <lowe.thiderman@gmail.com>

" Install this file as autoload/reinhardt.vim.

if exists('g:autoloaded_reinhardt') || &cp
  finish
endif
let g:autoloaded_reinhardt = '0.1'

let s:cpo_save = &cpo
set cpo&vim

" File finders {{{1

function! s:find_template(str)
  for app in values(s:apps)
    let fn = s:join(app, 'templates', a:str)
    if filereadable(fn)
      return fn
    endif
  endfor

  " Create a new in the current app; with directory creation
  " return s:new_template(a:str)
  " echo "No template found"
  return ""
endfunction

function! s:try_definitions()
  " Extended functionality of gf; line number hacking
  if filereadable(split(expand('<cWORD>'), ':')[0])
    return expand('<cWORD>')
  endif

  " The default functionality of gf
  let cfile = expand("<cfile>")
  if filereadable(cfile)
    return cfile
  endif

  let res = s:find_template(cfile)
  if res != "" | return res | endif

  if exists('g:loaded_linguist')
    let res = s:get_i18n_filepos(s:get_i18n_key())
    if res != "" | return res | endif
  endif
  return ''
endfunction

function! s:FindDefinition(cmd, ...) abort
  let res = s:try_definitions()
  if res == ''
    echo 'Nothing found under cursor, babe.'
    return
  endif

  let spl = split(res, ':')
  exe a:cmd spl[0]
  if len(spl) == 2
    call setpos('.', [0, spl[1], 0, 0])
    normal z.
  endif
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

function! s:relative_file(fn, ...)
  if a:fn == 'admin'
    let base = 'admin'
  elseif a:fn == 'init'
    let base = '__init__'
  elseif a:fn == 'middle'
    let base = 'middleware'
  else
    let base = a:fn . 's'
  endif

  let fn = s:join(a:0 ? s:apps[a:1] : s:get_current_app(), base)

  if isdirectory(fn)
    return fn
  else
    return fn . '.py'
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

function! s:get_management_commands()
  let cmds = []
  for app in values(s:apps)
    let dir = s:join(app, 'management', 'commands')
    let l = map(split(globpath(dir, '*'), '\n'), 'fnamemodify(v:val, ":t:r")')
    let l = filter(l, 'v:val != "__init__"')
    let cmds = extend(cmds, l)
  endfor
  return cmds
endfunction

" }}}
" i18n {{{1

function! s:get_current_lang() abort
  if exists('g:reinhardt_lang')
    return g:reinhardt_lang
  endif

  let langs = s:get_languages()
  if len(langs) == 0 || index(langs, 'en') >= 0
    " There are english files, or no files at all. Default to english.
    return 'en'
  else
    " There are languages, but none of them are english. Pick the first one.
    return langs[0]
  endif
endfunction

function! s:get_lang_file() abort
  let app = s:get_current_app()
  if app == ""
    return ""
  endif
  return s:join(app, 'locale', s:get_current_lang(), 'LC_MESSAGES', 'django.po')
endfunction

function! s:get_languages() abort
  let app = s:get_current_app()
  let dir = s:join(app, 'locale')

  if app == "" || !isdirectory(dir)
    " No languages; No locale has been created yet, or we are not in an app.
    return []
  endif

  return map(split(globpath(dir, '*'), '\n'), 'fnamemodify(v:val, ":t")')
endfunction

function! s:switch_lang(lang)
  let lang = a:lang
  if a:lang == -1 || a:lang == 1
    let langs = s:get_languages()
    let idx = index(langs, s:get_current_lang())

    if a:lang == -1
      let lang = langs[a:lang + idx]
    else
      let lang = idx + 1 < len(langs) ? langs[idx + 1] : langs[0]
    endif
  endif

  let g:reinhardt_lang = lang

  if exists('g:loaded_linguist')
    call s:LinguistPrint()
  endif
endfunction

" }}}
" Buffer setup {{{1

function! s:altmap(name, key)
  let k = g:reinhardt_mapkey
  exe 'nmap <buffer> <silent> '.k.a:key.' :R'.a:name.'<cr>'
  exe 'nmap <buffer> '.k.toupper(a:key).' :R'.a:name.' '
endfunction

function! s:addcmd(type, ...)
  let cpl = a:0 ? a:1 : 'Snake'
  let cmds = 'ESVT '
  let cmd = ''

  while cmds != ''
    let s = 'com! -nargs=* -complete=customlist,s:'.cpl.'cpl R'.cmd.a:type.' '
    let s = s . ':call s:Edit("'.a:type.'", "'.cmd.'", <f-args>)'
    exe s

    let cmd = strpart(cmds,0,1)
    let cmds = strpart(cmds,1)
  endwhile
endfunction


function! s:BufMappings()
  nnoremap <buffer> <silent> <Plug>ReinhardtFind :<C-U>call <SID>FindDefinition('edit')<CR>
  nnoremap <buffer> <silent> <Plug>ReinhardtNextLang :<C-U>call <SID>switch_lang(1)<CR>
  nnoremap <buffer> <silent> <Plug>ReinhardtPrevLang :<C-U>call <SID>switch_lang(-1)<CR>

  if !hasmapto("<Plug>ReinhardtFind")
    nmap <buffer> gf <Plug>ReinhardtFind
  endif

  command! -buffer -bar -nargs=? Rfind :call s:FindDefinition('edit', <f-args>)

  if exists('g:reinhardt_mapkey')
    let k = g:reinhardt_mapkey
    exe "nmap <buffer> ".k."<space> :Rswitch "

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

function! s:BufCommands()
  com! -buffer -nargs=1 -complete=customlist,s:Appcpl  Rswitch :call s:switch_app(<f-args>)
  com! -buffer -nargs=? -complete=customlist,s:Appcpl  Rcd     :call s:Cd('cd', <f-args>)
  com! -buffer -nargs=? -complete=customlist,s:Appcpl  Rlcd    :call s:Cd('lcd', <f-args>)
  com! -buffer -nargs=1 -complete=customlist,s:Langcpl Rlang   :call s:switch_lang(<f-args>)

  com! -buffer -nargs=0 Rlangnext :call s:switch_lang(1)
  com! -buffer -nargs=0 Rlangprev :call s:switch_lang(-1)

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
endfunction

" }}}
" Alternating and navigation {{{1

function! s:Edit(name, cmd, ...) abort
  let args = extend([a:name], a:000)
  let fn = call('s:switch_file', args)

  if fn == ""
    if a:0 && has_key(s:apps, a:1)
      return s:switch_app(a:1, a:name)
    endif

    call s:error('No file found for ' . a:name)
    return
  endif

  let cmd = 'edit'

  if a:cmd == "S"
    let cmd = "split"
  elseif a:cmd == "V"
    let cmd = "vsplit"
  elseif a:cmd == "T"
    let cmd = "tabedit"
  endif

  let args = a:000
  let fn = s:join(s:get_current_app(), fn)
  if isdirectory(fn) && a:0
    let fn = s:join(fn, a:1 . '.py')
    let args = args[1:]
  endif

  if exists('g:loaded_snakeskin') && s:is_snakeskinable(a:name)
    return call('SnakeskinEdit', extend([cmd, fn], args))
  endif

  exe cmd fn
endfunction

function! s:switch_app(name, ...)
  if !has_key(s:apps, a:name)
    call s:error(a:name . " - No such app.")
    return
  endif

  let app = s:apps[a:name]
  let cur = s:get_current_app()
  let fn = "models.py"
  let msg = ""

  if a:0
    let fn = s:relative_file(a:1)
  elseif cur != ""
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

    return s:default_file(app, dir)

  elseif a:kind == "template"
    if a:0
      return s:join('templates', a:1)
    endif

    return s:default_file(app, 'templates', 'base.html')

  elseif a:kind == "init"
    return '__init__.py'

  else
    return fnamemodify(s:relative_file(a:kind), ':t')
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
  let l = filter(l, '!isdirectory(v:val)')
  let l = map(l, 'substitute(v:val, "'.path.s:slash.'", "", "")')
  if a:mod != ""
    let l = map(l, "fnamemodify(v:val, '".a:mod."')")
  endif
  let l = filter(l, f)
  if len(l) == 1
    return [l[0] . ' ']
  endif
  return l
endfunction

function! s:Appcpl(A,P,L)
  " Complete all apps except the current one
  let appname = fnamemodify(s:get_current_app(), ":t")
  return sort(filter(keys(s:apps), 'v:val =~# "^".a:A && v:val != appname'))
endfunction

function! s:Langcpl(A,P,L)
  let l = s:get_languages()
  let lang = s:get_current_lang()
  return sort(filter(l, 'v:val =~# "^".a:A && v:val != lang'))
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

function! s:Snakecpl(A,P,L)
  if exists('g:loaded_snakeskin')
    let ret = []
    let spl = split(a:P)
    let fn = s:relative_file(substitute(spl[0], '\u', '', 'g'))

    if isdirectory(fn)
      let dir = fnamemodify(fn, ':t')
      if len(spl) == 1 || len(spl) <= 2 && a:P !~ '\s\+$'
        return s:cpl_dir(dir, '*', ':t:r', a:A, 'v:val != "__init__"')
      else
        let fn = s:join(s:get_current_app(), dir, spl[1] . '.py')
        return SnakeskinPythonCompletion(fn, spl[2:], a:A, a:P, a:L)
      endif
    endif

    return SnakeskinPythonCompletion(fn, spl[1:], a:A, a:P, a:L)
  else
    return s:Appcpl(a:A,a:P,a:L)
  endif
endfunction

" }}}
" manage.py {{{1

function! s:get_manage()
  let manage = 'manage.py'
  if exists('g:reinhardt_binaries')
    if has_key(g:reinhardt_binaries, g:reinhardt_root)
      let manage = g:reinhardt_binaries[g:reinhardt_root]
      return fnamemodify(s:join(g:reinhardt_root, manage), ':p')
    endif
  endif

  let manage = s:join(g:reinhardt_root, manage)
  if !executable(manage)
    let python = "python"
    if executable('python2')
      let python = "python2"
    endif
    let manage = python . " " . manage
  endif
  return manage
endfunction

function! s:Manage(...)
  exe "!" s:get_manage() join(a:000)
endfunction

function! s:Managecpl(A,P,L)
  let default = "cleanup compilemessages createcachetable dbshell diffsettings dumpdata flush inspectdb loaddata makemessages reset runfcgi runserver shell sql sqlall sqlclear sqlcustom sqlflush sqlindexes sqlinitialdata sqlreset sqlsequencereset startapp startproject syncdb test testserver validate"
  let cmds = extend(split(default), s:get_management_commands())
  return sort(filter(cmds, 'v:val =~# "^".a:A'))
endfunction

com! -nargs=+ -complete=customlist,s:Managecpl Reinhardt :call s:Manage(<f-args>)

" }}}
" Plugin integration {{{1
" Snakeskin {{{2

if exists('g:loaded_snakeskin')
  function! s:is_snakeskinable(name)
    let l = ['admin', 'form', 'middle', 'model', 'test', 'url', 'util', 'view']
    return index(l, a:name) != -1
  endfunction
endif

" }}}2
" Linguist {{{2

if exists('g:loaded_linguist')
  function! s:get_i18n_filepos(key) abort
    if a:key == ''
      return ''
    endif

    let fn = s:get_lang_file()
    let lnr = LinguistParse(fn).data[a:key][0]
    return fn .':'. lnr
  endfunction

  function! s:get_i18n_key(...)
    let line = a:0 ? a:1 : getline('.')
    let q = "[\"']"
    let rxp = '\<\(_\|ugettext\(_lazy\)\?\)('.q.'\(.\{-}\)'.q.')'
    let m = matchlist(line, rxp)
    if len(m) != 0
      return m[3]
    else
      return ""
    endif
  endfunction

  function! s:LinguistPrint() abort
    let key = s:get_i18n_key()
    if key != ""
      let fn = fnamemodify(s:get_lang_file(), ':p')
      if fn == ''
        return
      endif

      redraw
      call s:print_i18n_hud()

      let data = LinguistParse(fn)
      if !has_key(data, 'render')
        return s:print_i18n_error('lang file not found')
      endif

      let render = data.render(key)
      if render == {}
        return s:print_i18n_error('key not found in lang file')
      endif

      if has_key(render, 'plural')
        if key == render.plural.id
          let msg = render.plural.str[-1]
        else
          let msg = render.plural.str[0]
        endif
      else
        let msg = render.str
      endif

      if len(msg) > winwidth(0) - 12
        let msg = strpart(msg, 0, winwidth(0) - 15) . '...'
      endif

      echon msg
    else
      echo
    endif
  endfunction

  function! s:print_i18n_hud()
    let lang = s:get_current_lang()
    let langs = s:get_languages()
    let idx = index(langs, lang)

    echohl Delimiter
    echon '<'

    if len(langs) <= 2
      echohl Keyword
      echon lang

      if len(langs) == 2
        echohl Delimiter
        echon '/'
        echohl Comment
        call remove(langs, idx)
        echon langs[0]
      endif
    else
      echohl Comment
      echon langs[idx - 1]
      echohl Delimiter
      echon '/'
      echohl Keyword
      echon lang
      echohl Delimiter
      echon '/'
      echohl Comment
      echon idx + 1 < len(langs) ? langs[idx + 1] : langs[0]
    endif

    echohl Delimiter
    echon '>'
    echohl None
    echon ' '
  endfunction

  function! s:print_i18n_error(s)
    echohl Error
    echon '<'.a:s.'>'
    echohl None
    return
  endfunction

  augroup reinhardtLinguist
    au!
    au CursorMoved,CursorMovedI *.py call s:LinguistPrint()
  augroup END
endif

" }}}2
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
  call s:BufCommands()

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
