set -g fish_greeting ""
set -gx EDITOR vim
set -gx BAT_THEME "Catppuccin Mocha"
fish_add_path -g ~/.local/bin ~/go/bin ~/.cargo/bin

if status is-interactive
    fish_config theme choose catppuccin-mocha
    # Prompt & Navigation
    starship init fish | source
    zoxide init fish --cmd cd | source

    # fzf.fish: Vorschau mit bat/eza
    set -g fzf_preview_dir_cmd eza --all --color=always --icons
    set -g fzf_fd_opts --hidden --exclude=.git
    set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

    # Abkürzungen (expandieren beim Tippen)
    abbr -a ls  eza --icons --group-directories-first
    abbr -a ll  eza -l --icons --git --group-directories-first
    abbr -a la  eza -la --icons --git --group-directories-first
    abbr -a lt  eza --tree --level=2 --icons
    abbr -a cat bat
    abbr -a top btop
    abbr -a lg  lazygit
    abbr -a g   git
    abbr -a gs  git status
    abbr -a ga  git add
    abbr -a gc  git commit
    abbr -a gp  git push
    abbr -a gl  git pull
    abbr -a gd  git diff
    abbr -a gco git checkout
    abbr -a gsw git switch
    abbr -a glog git log --oneline --graph --decorate
    abbr -a .. cd ..
    abbr -a ... cd ../..
end
