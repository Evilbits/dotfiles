# dotfiles
My usual setup. Note that the Arch setup is in a separate folder and does not have an automatic setup script.

## installation

Install Cascadia Code font.
```sh
$ sudo apt-get install fonts-cascadia-code -y
$ sudo fc-cache -fv
```

To install the dotfiles simply run the linker.
```sh
$ ./linker.sh
```

### Omnisharp C# setup
* Install newest Mono preview: https://www.mono-project.com/download/preview/#download-lin
* Install Omnisharp using `LspInstall omnisharp`
