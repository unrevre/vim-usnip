" Minimal snippeting plugin
" Maintainer: unrevre <unrevre@gmail.com>
" License: MIT

if exists('g:loaded_usnip')
    finish
endif
let g:loaded_usnip = 1

inoremap <expr> <silent> <Plug>(usnip-next) usnip#should_trigger() ?
            \"x\<bs>\<c-o>:call usnip#expand(v:false)\<cr>" : "\<tab>"
snoremap <expr> <silent> <Plug>(usnip-next) usnip#should_trigger() ?
            \"\<esc>:call usnip#expand(v:true)\<cr>" : "\<tab>"

" add the default mappings if the user hasn't defined any
if !hasmapto('<Plug>(usnip-next)')
    imap <unique> <Tab> <Plug>(usnip-next)
    smap <unique> <Tab> <Plug>(usnip-next)
endif

if &completefunc is# ''
    set completefunc=usnip#complete
endif

augroup usnip
    au!
    autocmd CompleteDone * call usnip#done(v:completed_item)
augroup END
