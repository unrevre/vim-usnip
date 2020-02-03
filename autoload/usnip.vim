let s:nsdelim = get(g:, 'usnip_nsdelim', '{{+')
let s:nedelim = get(g:, 'usnip_nedelim', '+}}')
let s:fsdelim = get(g:, 'usnip_fsdelim', '{{-')
let s:fedelim = get(g:, 'usnip_fedelim', '-}}')
let s:evalmarker = get(g:, 'usnip_evalmarker', '~')
let s:backrefmarker = get(g:, 'usnip_backrefmarker', '\\~')
let s:startmarker = get(g:, 'usnip_startmarker', '%##%')

let s:ndelim = '\V' . s:nsdelim . '\(\.\{-}\)' . s:nedelim
let s:fdelim = '\V' . s:fsdelim . '\(\.\{-}\)' . s:fedelim

func! usnip#should_trigger() abort
    silent! unlet! s:snippetfile
    let s:token = matchstr(getline('.'), '\v\f+%' . col('.') . 'c>')

    let l:dirs = join(s:directories(), ',')
    let l:all = globpath(l:dirs, s:token, 0, 1)
    call filter(l:all, {_, path -> filereadable(path)})

    if len(l:all) > 0
        let s:snippetfile = l:all[0]
        return 1
    endif

    return search(s:ndelim . '\|' . s:fdelim, 'e')
endfunc

" main func, called on press of Tab (or whatever key usnip is bound to)
func! usnip#expand(smode) abort
    if exists('s:snippetfile')
        " reset placeholder text history (for backrefs)
        let s:placeholder_texts = []
        let s:placeholder_text = ''
        " move to start of snippet token
        call searchpos('\V' . s:token . '\>', 'bc', line('.'))
        " check character before token
        let l:bc = col('.') > 1 ? getline('.')[col('.') - 2] : ' '
        " remove snippet token (allows one non-word-character prefix)
        normal! "_de
        let l:lns = readfile(s:snippetfile)
        " adjust the indentation, use the current line as reference
        if len(l:lns) > 1
            let l:ws = matchstr(getline(line('.')), '^\s\+')
            let l:lns[1:-1] = map(l:lns[1:-1],
                \'empty(v:val) ? v:val : l:ws . v:val')
        endif
        if strlen(getline('.')) > col('.')
            let l:old_s = @s
            " delete line after snippet token
            normal! "sD
            " join saved line to last line of snippet
            let l:lns[-1] = l:lns[-1] . getreg('s')
            let @s = l:old_s
        endif
        " insert marker for start of snippet
        let l:lns[0] = s:startmarker . l:lns[0]
        " insert the snippet
        call append(line('.'), l:lns)
        " join the snippet at the current position
        normal! J
        " select the first placeholder
        call s:select_placeholder(l:bc)
    else
        " Make sure '< mark is set so the normal command won't error out.
        if getpos("'<") == [0, 0, 0, 0]
            call setpos("'<", getpos('.'))
        endif

        " save cursor position
        let l:cpos = getcurpos()
        let l:adjust = (a:smode || l:cpos[4] > l:cpos[2]) ? '' : 'h'
        " save the current placeholder's text so we can backref it
        let l:old_s = @s
        " adjust cursor position if activated from insert mode
        execute 'normal! ' . l:adjust . 'ms"syv`<`s'
        let s:placeholder_text = @s
        let @s = l:old_s
        " restore cursor position
        call setpos('.', l:cpos)
        " jump to the next placeholder
        call s:select_placeholder('')
    endif
endfunc

" this is the function that finds and selects the next placeholder
func! s:select_placeholder(bc) abort
    " don't clobber s register
    let l:old_s = @s

    " get the contents of the placeholder
    " we use /e here in case the cursor is already on it (which occurs ex.
    "   when a snippet begins with a placeholder)
    " we also use keeppatterns to avoid clobbering the search history /
    "   highlighting all the other placeholders
    try
        " gn misbehaves when 'wrapscan' isn't set (see vim's #1683)
        let [l:ws, &ws] = [&ws, 1]
        silent keeppatterns execute 'normal! /' . s:ndelim . "/e\<cr>gn\"sy"
        let l:delim = s:ndelim
    catch /E486:/
        " there's no normal placeholder
        " usnip#should_trigger() removes need for try-catch
        silent keeppatterns execute 'normal! /' . s:fdelim . "/e\<cr>gn\"sy"
        let l:delim = s:fdelim
    finally
        let &ws = l:ws
    endtry

    " save the contents of the previous placeholder (for backrefs)
    call add(s:placeholder_texts, s:placeholder_text)

    " remove the start and end delimiters
    let @s = substitute(@s, l:delim, '\1', '')

    " is this placeholder marked as 'evaluate'?
    if @s =~ '\V\^' . s:evalmarker
        " remove the marker
        let @s = substitute(@s, '\V\^' . s:evalmarker, '', '')
        " substitute in any backrefs
        let @s = substitute(@s, '\V' . s:backrefmarker . '\(\d\)',
            \"\\=\"'\" . substitute(get(
            \    s:placeholder_texts,
            \    len(s:placeholder_texts) - str2nr(submatch(1)), ''
            \), \"'\", \"''\", 'g') . \"'\"", 'g')
        " evaluate what's left
        let @s = eval(@s)
    endif

    " remove extraneous whitespace from joining lines
    if exists('s:snippetfile')
        let l:wsc = a:bc !=# ' ' ? ' ' : ''
        silent keeppatterns execute ':%s/\V' . l:wsc . s:startmarker . '//'
        " jump to and highlight placeholder
        silent keeppatterns execute 'normal! /' . l:delim . "/e\<cr>gno\<esc>"
    endif

    if empty(@s)
        " remove placeholder
        let l:cpos = getcurpos()
        normal! gv"_d
        call setpos('.', l:cpos)
    else
        " paste the placeholder's default value in and enter select mode on it
        execute "normal! gv\"spgv\<C-g>"
    endif

    " restore old value of s register
    let @s = l:old_s
endfunc

func! usnip#done(item) abort
    if empty(a:item)
        return
    endif

    if match(a:item.word, s:ndelim) != -1
        let s:placeholder_texts = []
        let s:placeholder_text = ''

        call s:select_placeholder('')
    endif
endfunc

func! usnip#complete(findstart, base) abort
    if a:findstart
        " Locate the start of the word
        let l:line = getline('.')
        let l:start = col('.') - 1
        while l:start > 0 && l:line[l:start - 1] =~? '\a'
            let l:start -= 1
        endwhile

        return l:start
    endif

    " Load all snippets that match.
    let l:dirs = join(s:directories(), ',')
    let l:all = globpath(l:dirs, a:base, 0, 1)
    call filter(l:all, {_, path -> filereadable(path)})
    call map(l:all, funcref('s:build_comp'))
    call sort(l:all, {a, b -> a.abbr ==? b.abbr ? 0 : a.abbr > b.abbr ? 1 : -1})

    return l:all
endfunc

func! s:build_comp(_, path) abort
    let l:name = fnamemodify(a:path, ':t:r')
    let l:content = readfile(a:path)

    return {
                \ 'icase': 1,
                \ 'dup': 1,
                \ 'kind': 's',
                \ 'word': l:name,
                \ 'abbr': l:name,
                \ 'menu': l:content[0],
                \ 'info': join(l:content, "\n"),
                \ }
endfunc

func! s:directories() abort
    let l:filetypes = split(&filetype, '\.')
    let l:ret = []

    for l:dir in get(g:, 'usnip_dirs', ['~/.vim/snippets'])
        let l:ret += map(l:filetypes, {_, val -> l:dir.'/'.val}) + [l:dir]
    endfor

    return l:ret
endfunc
