
Arch repo: arch/os/x86_64/ - add `[rind]\nServer = https://reon-org.github.io/packager/arch/os/$arch`

```
curl https://reon-org.github.io/packager/rind-gpg-public.asc -o rind-gpg-public.asc
pacman-key --add rind-gpg-public.asc
pacman-key --lsign-key $(gpg --with-colons rind-gpg-public.asc | head -1 | cut -d: -f5)
```


Void repo: void/<arch>/ + void/repodata/ - add repository=https://reon-org.github.io/packager/void
```
xbps-install -S
xbps-install rind
```
