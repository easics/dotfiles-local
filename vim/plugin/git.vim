
function s:GitSystem(command)
  return substitute(system(a:command), '\n$', '', '')
endfunction

function s:isUnderGit(file)
  let l:gitted=s:GitSystem("git ls-files -- ". a:file)
  if empty(l:gitted) || l:gitted != a:file
    return 0
  else
    return 1
  endif
endfunction

function s:GitMakeVersion(file, commitid)
  let l:tmpfile=tempname()
  "let l:patchfile=tempname()

  let l:commitid=substitute(a:commitid, ' *$', '', '')
  let l:filepath=s:GitSystem("git ls-files --full-name ". a:file)
  call s:GitSystem("git show ". l:commitid .":". l:filepath . " > " . l:tmpfile)
  return l:tmpfile
endfunction

function GitDiff(...)
  let repkeep=&report
  set report=10
  let l:file=expand('%')
  if !s:isUnderGit(l:file)
    echo "Not under revision control"
    return
  endif
  if a:0 < 2
    if a:0 == 0
      let l:commitid='HEAD'
    elseif a:0 == 1
      let l:commitid=a:1
    endif

    let l:versionfile = s:GitMakeVersion(l:file, l:commitid)
    diffoff!
    silent execute "vert diffsplit " . l:versionfile
    call s:GitSetStatusLine(l:commitid, 0)
  else
    if a:0 ==2
      let l:versionfile1 = s:GitMakeVersion(l:file, a:1)
      let l:versionfile2 = s:GitMakeVersion(l:file, a:2)
      silent exe ":e ".l:versionfile1
      call s:GitSetStatusLine(a:1, 0)
      silent exe "vert diffsplit " . l:versionfile2
      call s:GitSetStatusLine(a:2, 1)
    else
      let l:versionfile1 = s:GitMakeVersion(l:file, a:1)
      let l:versionfile2 = s:GitMakeVersion(l:file, a:2)
      let l:versionfile3 = s:GitMakeVersion(l:file, a:3)
      silent exe ":e ".l:versionfile2
      call s:GitSetStatusLine(a:2, 1)
      silent exe "vert diffsplit " . l:versionfile1
      call s:GitSetStatusLine(a:1, 0)
      silent exe "vert diffsplit " . l:versionfile3
      call s:GitSetStatusLine(a:3, 2)
    endif
  endif
  let &report=repkeep
endfunction

function GitSelect()
  let l:file=expand('%')
  if !s:isUnderGit(l:file)
    echo "Not under revision control"
    return
  endif
  new
  let repkeep=&report
  set report=10
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal nowrap
  setlocal modifiable
  setlocal noro
  exe "$put ='".'\"'." git.vim version 0.1'"
  exe "$put ='".'\"'." - press ENTER on a line to compare that commit to your ".
        \ "local version'"
  exe "$put ='".'\"'." - press m on a line to mark that commit for comparison'"
  exe "$put ='".'\"'."   you can put up to 2 marks. This gives a 3-way diff'"
  exe "$put ='".'\"'."   mark1 <-> mark2 <-> commit line where you press ENTER'"
  let l:filestate=s:GitGetFileState(l:file)
  exe "$put ='".'\"'." state : ".l:filestate."'"
  exe "$put ='".'\"'''
  exe "$put ='".'\"'." revision log of file ".l:file."'"

  let l:tmpfile=tempname()
  call s:GitSystem("git log " . l:file . " > " . l:tmpfile)
  let l:parse_state = 0
  for line in readfile(l:tmpfile)
    if l:parse_state == 0 " looking for 'commit ...'
      if strpart(line, 0, 7) == 'commit '
        let l:commitid=strpart(line, 7)
        let l:parse_state = 1
      endif
    elseif l:parse_state == 1 " looking for Author line
      if strpart(line, 0, 8) == 'Author: '
        let l:author=substitute(strpart(line, 8), ' <.*', '', '')
        let l:parse_state = 2
      endif
    elseif l:parse_state == 2 " looking for empty line (starting commit msg)
      if empty(line)
        let l:parse_state = 3
      endif
    elseif l:parse_state == 3 " read 1 line of commit msg
      let l:commit_msg = line
      let l:parse_state = 4
      exe "$put ='".l:commitid.l:commit_msg." = ".l:author"'"
    elseif l:parse_state == 4 " looking for empty line (ending commit msg)
      if empty(line)
        let l:parse_state = 0
      endif
    endif
  endfor
  exe "$put ='".'\"'''
  exe "$put ='".'\"'." merge stages'"
  exe "$put =':1                                          Ancestor'"
  exe "$put =':2                                          Ours'"
  exe "$put =':3                                          Theirs'"
  call s:GitAddBranches()
  1d
  setlocal noma nomod ro
  noremap <silent> <buffer> <cr> :call <SID>GitDiffSelect()<cr>
  noremap <silent> <buffer> m :call <SID>GitDiffMark()<cr>
  let b:bufmarkers = []
  let s:statuslines = []

  let &report=repkeep

endfunction

function s:GitDiffSelect()
  let l:commitid=getline(".")
  if l:commitid =~ '^"'
    return
  endif
  let l:commitid1=strpart(l:commitid, 0, 40)
  let s:statuslines += [strpart(l:commitid, 44)]
  if empty(b:bufmarkers)
    bwipe
    call GitDiff(l:commitid1)
  else
    if len(b:bufmarkers) == 1
      if line('.') == b:bufmarkers[0]
        bwipe
        call GitDiff(l:commitid1)
      else
        let l:line = getline(b:bufmarkers[0])
        let l:commitid2=strpart(l:line, 0, 40)
        let s:statuslines += [strpart(l:line, 44)]
        bwipe
        call GitDiff(l:commitid1, l:commitid2)
      endif
    else
      if line('.') == b:bufmarkers[0]
        let l:line = getline(b:bufmarkers[0])
        let l:commitid2=strpart(l:line, 0, 40)
        let s:statuslines += [strpart(l:line, 44)]
        bwipe
        call GitDiff(l:commitid1, l:commitid2)
      elseif line('.') == b:bufmarkers[1]
        let l:line = getline(b:bufmarkers[0])
        let l:commitid2=strpart(l:line, 0, 40)
        let s:statuslines += [strpart(l:line, 44)]
        bwipe
        call GitDiff(l:commitid1, l:commitid2)
      else
        let l:line = getline(b:bufmarkers[0])
        let l:commitid2=strpart(l:line, 0, 40)
        let s:statuslines += [strpart(l:line, 44)]
        let l:line = getline(b:bufmarkers[1])
        let l:commitid3=strpart(l:line, 0, 40)
        let s:statuslines += [strpart(l:line, 44)]
        bwipe
        call GitDiff(l:commitid1, l:commitid2, l:commitid3)
      endif
    endif
  endif
endfunction

function s:GitDiffMark()
  let l:commitid=getline(".")
  if l:commitid =~ '^"'
    return
  endif
  let l:oldbufmarkers = b:bufmarkers[:]
  let l:current_line=line(".")
  let l:index = 0
  let l:on_existing_marker = 0
  for marker in b:bufmarkers
    if marker == l:current_line
      call remove(b:bufmarkers, index)
      let l:on_existing_marker = 1
      break
    endif
    let l:index = l:index + 1
  endfor

  if l:on_existing_marker == 0
    if len(b:bufmarkers) == 2
      let b:bufmarkers = b:bufmarkers[1:1]
    endif
    let b:bufmarkers = b:bufmarkers + [l:current_line]
  endif

  " update markers
  set ma noro
  " delete old markers
  for marker in l:oldbufmarkers
    keepjumps exe "normal " . marker . "gg041 2r "
  endfor
  " show new markers
  let l:index = 1
  for marker in b:bufmarkers
    keepjumps exe "normal " . marker . "gg041 RM".l:index
    let l:index = l:index + 1
  endfor
  set noma ro

endfunction

function s:GitGetFileState(file)
  let l:filestate=s:GitSystem("git ls-files -t -- ". a:file)
  if l:filestate[0] == "H"
    return "Unchanged"
  elseif l:filestate[0] == "M"
    return "Unmerged"
  elseif l:filestate[0] == "R"
    return "Removed"
  elseif l:filestate[0] == "C"
    return "Modified"
  elseif l:filestate[0] == "K"
    return "To be killed"
  elseif l:filestate[0] == "?"
    return "Unknown"
  else
    return "Unknown state"
  endif
endfunction

function s:GitAddBranches()
  exe "$put ='".'\"'''
  exe "$put ='".'\"'." branches'"
  let l:tmpfile=tempname()
  call s:GitSystem('git branch > ' . l:tmpfile)
  for line in readfile(l:tmpfile)
    exe "$put ='".printf("%-40s    %s branch", line[2:], line[2:])."'"
  endfor
endfunction

function s:GitSetStatusLine(default, stage)
  if len(s:statuslines) > a:stage
    let b:gitstatusline=s:statuslines[a:stage]
  else
    let b:gitstatusline=a:default
  endif
  exe ":setlocal statusline=%{b:gitstatusline}"
endfunction
