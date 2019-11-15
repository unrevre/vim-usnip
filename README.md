# μSnip

Minimalistic snippet management for Vim.

## Installation

Check your favourite plugin manager or `:h pack-add` if you do not use any.

## Usage

This plugin uses `:h compl-function` to expand snippets. This also requires it
to attach to the `CompleteDone` autocommand, which has some changes to default
behaviour:

- Completions that contain `NUL` will have that character replaced by newline.
- At least one pair of delimiters (`{{++}}` by default) is required in any
  completion.

`<Tab>` in insert mode is remapped in a way that it will not work if a
delimiter pair exists elsewhere in the buffer. `i_CTRL-T` and `i_CTRL-D` may be
used instead.

Completions that modify existing text are handled properly, provided the cursor
is returned to the appropriate location.

## Credits

All authors of [usnip.vim][usnip] and [vim-minisnip][minisnip].

[usnip]: https://github.com/Hauleth/usnip.vim
[minisnip]: https://github.com/joereynolds/vim-minisnip
