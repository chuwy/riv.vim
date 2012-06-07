"=============================================
"    Name: fold.vim
"    File: fold.vim
"  Author: Rykka G.Forest
"  Update: 2012-06-07
" Version: 0.5
"=============================================
let s:cpo_save = &cpo
set cpo-=C

"{{{ folding 

fun! riv#fold#expr(row) "{{{
    
    let b:singal = 0
    let p_line = getline(a:row-1)
    let c_line = getline(a:row)
    let n_line = getline(a:row+1)
     
    " we could not use multiline match here
    let c_match = matchstr(c_line,g:_RIV_c.ptn.section)
    let n_match = matchstr(n_line,g:_RIV_c.ptn.section)

    " using index(list,item) is a bit quicker than dict[item] here
    " 1.6x:1.7x sec at 100000 time
    if a:row == 1 
        let b:dyn_sec_list = []
        unlet! b:fdl_before_list b:fdl_before_exp b:foldlevel b:fdl_cur_list
    endif

    if !empty(c_match) && empty(n_match) && getline(a:row+2) == c_line
        let idx = index(b:dyn_sec_list, c_match[1])+1
        if idx == 0
            call add(b:dyn_sec_list,c_match[1])
            let idx = len(b:dyn_sec_list)
        endif
        let b:foldlevel = idx
        return ">".idx
    elseif !empty(n_match) && c_line !~ g:_RIV_c.ptn.blank
        if p_line =~ g:_RIV_c.ptn.blank
            let idx = index(b:dyn_sec_list,n_match[1])+1
            if idx == 0
                call add(b:dyn_sec_list,n_match[1])
                let idx = len(b:dyn_sec_list)
            endif
            let b:foldlevel = idx
            return ">".idx
        elseif p_line == n_line
            let idx = index(b:dyn_sec_list,n_match[1])+1
            if idx == 0
                call add(b:dyn_sec_list,n_match[1])
                let idx = len(b:dyn_sec_list)
            endif
            let b:foldlevel = idx
            return idx
        endif
    endif
    
    "(ExplicitMarkup Fold)
    " The line start the ExplicitMarkup 
    " b:fdl_before_exp : foldlevel of document before ExplicitMarkup
    " NOTE: as the line in exp_cluster_ptn syntax !~ g:_RIV_c.ptn.S_bgn, 
    "       we can use it to check for performance. 
    "       but only use it with lines next to exp_cluster_ptn.
    " NOTE: differece between synId and synstack:
    "       for an empty line in ExplicitMarkup's region. 
    "       synID  will return 0, 
    "       synstack will return the top syn item:[n].
    "       exp_cluster_ptn is always a top syn-item as defined in rst.vim.
    if c_line =~ g:_RIV_c.ptn.exp && n_line !~ g:_RIV_c.ptn.S_bgn
        let b:singal = 1
        let b:foldlevel = exists("b:foldlevel") ?
                    \ b:foldlevel : 0
        " NOTE: for continuous exp_markup line  
        "       can not get the last fdl before first one.
        "       it depends on whether the first exp_markup have
        "       an blank endline or not.
        "       so we will not change it if it's 7
        if b:foldlevel!= 15
            let b:fdl_before_exp = b:foldlevel 
        endif
        let b:foldlevel = 15
        return ">15"
    endif
    
    " the line finish ExplicitMarkup (one blank line '\_^\s*\n\_^\S')
    " ( ExplicitMarkup ends with '^..\_s' or '\_^\s*\n\_^\S')
    " NOTE: as we will leave one blank line. 
    "       so no 2-line-fold issue with blank line
    if c_line =~ g:_RIV_c.ptn.blank && n_line =~ g:_RIV_c.ptn.S_bgn && p_line =~ g:_RIV_c.ptn.s_or_exp
        let b:singal = 2
        if synIDattr(get(synstack(a:row,1),0),"name") =~ g:_RIV_c.ptn.exp_cluster
            let b:foldlevel = exists("b:fdl_before_exp") ?
                        \ b:fdl_before_exp : 0
            let t = b:foldlevel
            return t
        endif
    endif
    
    " fold list depend on indent
    if c_line =~ g:_RIV_c.ptn.list
                \ && indent(a:row) < indent(nextnonblank(a:row+1))
        " some are 2, some are 3..
        let t = indent(a:row)/2 + 8
        " don't update fdl_before if in a fdl list.
        if !exists("b:fdl_cur_list") || b:fdl_cur_list==0
            let b:fdl_before_list = exists("b:foldlevel") ? b:foldlevel : 0
        endif
        let b:fdl_cur_list = 1
        let b:foldlevel = t
        return '>'.t
    endif
    
    " leave a blank line or not?
    " if (c_line =~ g:_RIV_c.ptn.blank && n_line=~g:_RIV_c.ptn.S_bgn ) || (c_line=~g:_RIV_c.ptn.S_bgn)
    if (c_line=~g:_RIV_c.ptn.S_bgn)
        if exists("b:fdl_cur_list") && b:fdl_cur_list==1
            let b:foldlevel = exists("b:fdl_before_list") ? b:fdl_before_list : 0
            let t = b:foldlevel
            let b:fdl_cur_list=0
            return t
        endif
    endif

    " fold table
    if c_line=~g:_RIV_c.ptn.tbl
        return 10
    endif

    " NOTE: fold-expr will eval last line first , then eval from start.
    " NOTE: it is too slow to use "="
    " XXX:  could not using foldlevel cause it returns -1
    let t = exists("b:foldlevel") ?  b:foldlevel : 0
    return t
    
endfun "}}}
fun! riv#fold#text() "{{{
    " NOTE: if it's three row title. show the content of next line.
    let line = getline(v:foldstart)

    if line =~ g:_RIV_c.ptn.section 
        let line = getline(v:foldstart+1)
    endif
    if line=~g:_RIV_c.ptn.tbl
        if exists("b:rst_table[v:foldstart]")
            let line = "TABLE:  ".b:rst_table[v:foldstart]
        else
            let line = "TABLE:  ".getline(v:foldstart+1)
        endif
    endif
    let m_line = winwidth(0)-11
    if len(line) <= m_line
        let line = line."  ".repeat('-',m_line) 
    endif
    let line = printf("%-".m_line.".".(m_line)."s",line)
    if v:foldlevel <= 3
        let dash = printf("%4s",repeat("<",v:foldlevel))
    else
        let dash = printf("%4s","<<+")
    endif
    let num = printf("%5s",(v:foldend-v:foldstart))
    return line."[".num.dash."]"
endfun "}}}
"}}}

let &cpo = s:cpo_save
unlet s:cpo_save