if (has("termguicolors"))
  set termguicolors
endif

set number

call plug#begin()

Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'

Plug 'airblade/vim-gitgutter'

Plug 'tpope/vim-sleuth'
Plug 'editorconfig/editorconfig-vim'

call plug#end()

set expandtab
set tabstop=2
set shiftwidth=2
