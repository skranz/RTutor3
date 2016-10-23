
rtutor.default.whitelist = function(wl.funs=NULL, wl.calls=NULL, bl.funs=NULL, bl.vars=c(".GlobalEnv",".BaseNamespaceEnv")) {
  nlist(wl.funs, wl.calls, bl.funs, bl.vars)
}


rtutor.check.whitelist = function(call, ps = get.ps()) {
  if (!isTRUE(ps$check.whitelist)) {
    return(list(ok=TRUE, msg=""))
  }
  restore.point("rtutor.check.whitelist")
  
  wl = ps$wl
  whitelistcalls::check.whitelist(call, wl.funs=wl$wl.funs,wl.vars = wl$wl.vars,wl.calls = wl$wl.calls,bl.funs = wl$bl.funs, bl.vars = wl$bl.vars)
}

rtutor.whitelist.report = function(rps, te, wl=rtutor.default.whitelist()) {
  restore.point("rtutor.make.whitelist")
  library(whitelistcalls)
  code = suppressWarnings(knitr::purl(text=te$out.txt, quiet=TRUE))
  expr = parse(text=code)


  fb.calls = find.forbidden.calls(expr,wl.funs=wl$wl.funs, wl.vars=wl$wl.vars,wl.calls = wl$wl.calls, bl.funs = wl$bl.funs, bl.vars = wl$bl.vars )
  

}
