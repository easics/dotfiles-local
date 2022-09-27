function! RelPath()
  let l:curdir = getcwd()
  let l:fullpath = expand('%:p:h')

  let l:curdirlist = split(l:curdir, "/", 0)
  let l:fullpathlist = split(l:fullpath, "/", 0)

  let l:idx = 0
  let l:different = 0
  let l:result = ""
  for l:c in l:curdirlist
    let l:f = get(l:fullpathlist, l:idx, "")
    if l:different == 0 && l:c != l:f
      let l:different = 1
    endif
    if l:different
      let l:result = "../" . l:result . l:f
      if !empty(l:f)
        let l:result .= "/"
      endif
    endif
    let l:idx = l:idx + 1
  endfor

  for l:f in l:fullpathlist[l:idx : -1]
    let l:result = l:result . l:f . "/"
  endfor
  if empty(result)
    return expand('%:t')
  else
    let l:result .= expand('%:t')
    let l:fullpath = expand('%:p')
    if len(l:result) <= len(l:fullpath)
      return l:result
    else
      return l:fullpath
    end
  endif
endfunction
