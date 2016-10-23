secure.base.env = function(ps=get.ps()) {
  env = new.env(parent=globalenv())
  env$get.ps = function(...) {
    ps
  }
  env
}

# Run check.chunk within RAppArmor eval.secure
secure.check.chunk = function(chunk.ind, verbose=FALSE,stud.code=ps$cdt$stud.code[[chunk.ind]], task.env=make.chunk.task.env(chunk.ind, ps), expect.change = FALSE, store.output=TRUE, noeval = isTRUE(ps$noeval), precomp=isTRUE(ps$precomp), ..., ps = get.ps()) {

  restore.point("secure.check.chunk")
  
  ck = ps$cdt[chunk.ind,]
  chunk.name = ck$chunk.name

  ps$cdt$stud.code[chunk.ind] = stud.code
  ps$cdt$old.stud.code[chunk.ind] = stud.code
  ps$cdt$is.solved[chunk.ind] = FALSE
  
  ps$ex.ind = ck$ex.ind
  ps$chunk.ind = chunk.ind
  ps$chunk.name = chunk.name
  ps$chunk.console.out = ""
  
  if (verbose)
    display("securely check chunk ", chunk.name," ...")

  ps$success.log = NULL
  ps$success.message = ""
  ps$failure.message  = "No failure message recorded"
  ps$warning.messages = list()
  ps$check.date = Sys.time()

  has.error = FALSE
  ps$stud.expr.li = NULL
  if (verbose) {
    display("parse stud.code...")
  }

  if (!is.false(ps$catch.errors)) {
    tryCatch( ps$stud.expr.li <- base::parse(text=stud.code, srcfile=NULL),
              error = function(e) {
                ps$failure.message=paste0("parser error: ",geterrmessage())
                has.error <<- TRUE
              })
  } else {
    ps$stud.expr.li <- base::parse(text=stud.code, srcfile=NULL)
  }
  if (has.error) {
    log.event(type="check_chunk",chunk=chunk.ind, ex=ck$ex.ind,e.ind=0,code=stud.code, ok=FALSE,message=ps$failure.message)
    update.ups.chunk.check(passed=FALSE,chunk.ind=chunk.ind, save=TRUE, ps=ps)
    return(FALSE)
  }


  if (isTRUE(ps$check.whitelist)) {
    if (verbose)
      display("check whitelist")
    res = rtutor.check.whitelist(ps$stud.expr.li,ps=ps)
    if (!res$ok) {
      ps$failure.message=paste0("security error: ",res$msg)
      log.event(type="check_chunk",chunk=chunk.ind, ex=ck$ex.ind,e.ind=0,code=stud.code, ok=FALSE,message=ps$failure.message)
      update.ups.chunk.check(passed=FALSE,chunk.ind=chunk.ind, save=TRUE, ps=ps)

      return(FALSE)
    }
  }

  ps$task.env = task.env
  ps$cdt$task.env[[chunk.ind]] = task.env

  ps$stud.seed = as.integer(Sys.time())
  set.seed(ps$stud.seed)

  call = quote(inner.secure.check.chunk())
  
  ps$in.secure.eval = TRUE
  set.ps(ps)
  ps = get.ps()
  res = try(RTutor::rtutor.eval.secure(call))
  ps$in.secure.eval = FALSE

    
  if (is(res,"try-error")) {
    res = list(ok=FALSE, ps.fields=list(failure.message=ps$failure.message, success.message="", success.log=NULL, e.ind=0, tdt.ind=0, task.env=ps$task.env, chunk.console.out=as.character(res)))
  }
  
  
  fields = res$ps.fields

  ps$chunk.console.out = as.character(fields$chunk.console.out)
  
  ps$failure.message = as.character(fields$failure.message)
  ps$success.message = as.character(fields$ps$success.message)
  ps$success.log = sapply(fields$success.log, as.character)

  ps$e.ind = as.integer(fields$e.ind)
  ps$tdt.ind = as.integer(fields$tdt.ind)
  
  ps$cdt$is.solved[[chunk.ind]] = isTRUE(res$ok)
  # copy task.env
  copy.into.env(dest=ps$task.env, source=fields$task.env)
  
  ck = ps$cdt[chunk.ind,]
  
  set.ps(ps)
  
  if (!is.na(ck$award.name)) {
    give.award(ck$award.name, ps=ps)
    if (isTRUE(ps$is.shiny))
      show.shiny.award(ck$award.name)
  }
  

  log.event(type="check_chunk",chunk=chunk.ind, ex=ck$ex.ind,e.ind=0,code=stud.code, ok=FALSE,message=ps$failure.message)
  update.ups.chunk.check(passed=res$ok,chunk.ind=chunk.ind, save=TRUE, ps=ps)
  
  return(res$ok)
}


# The eval part of secure.check chunk
# will be called with eval.secure
inner.secure.check.chunk = function(chunk.ind=ps$chunk.ind,ps=get.ps(), verbose=FALSE,stud.code=ps$cdt$stud.code[[chunk.ind]], noeval = isTRUE(ps$noeval), precomp=isTRUE(ps$precomp)) {
  restore.point("inner.secure.check.chunk")

#   all.txt = NULL
#   
#   cat = function(...) {
#     txt = paste0(..., sep="\n")
#     all.txt <<- c(all.txt, txt)
#     writeLines(all.txt, "debug.txt")
#   }
#   print = function(x,...) {
#     txt = capture.output(base::print(x,...))
#     all.txt <<- c(all.txt, txt)
#     writeLines(all.txt, "debug.txt")
#     
#   }  
#   cat("\n\n******************************************")
#     
#   cat("\ninner.secure.check.chunk\n chunk.ind:", chunk.ind,"\n")

  task.env = ps$task.env
  ck = ps$cdt[chunk.ind,]

  
  #stop("analyse below")
  test.li = ck$test.expr[[1]]

  if (verbose)
    display("inner.secure.check.chunk ", chunk.name," ...")


  if (verbose) {
    display("eval stud.code...")
  }
  ps$e.ind = 0
  has.error = FALSE

  # run student code in task.env
  if (!isTRUE(ps$noeval)) {
    has.error = !stepwise.eval.stud.expr(stud.expr=ps$stud.expr.li,task.env=task.env, store.output=FALSE)
    if (has.error) {
      return(inner.secure.check.chunk.return(FALSE))
    }
  }

  had.warning = FALSE
  if (verbose) {
    display("run tests...")
  }

  e.ind = 1

  tdt.ind = which(ps$tdt$chunk.ps.ind == chunk.ind)[1]-1

  # Turn graphics device off
  if (isTRUE(ps$use.null.device)) {
    try(png("NUL"), silent=TRUE)
    on.exit(try(dev.off(), silent=TRUE),add = TRUE)
  }
  # Back to normal graphics device


  for (e.ind in seq_along(ck$e.li[[1]])) {
    ps$e.ind = e.ind
    tests = ck$test.expr[[1]][[e.ind]]
    test.ind = 1
    for (test.ind in seq_along(tests)){
      tdt.ind = tdt.ind +1
      ps$tdt.ind = tdt.ind
      test = tests[[test.ind]]
      ps$success.message = NULL
      if (verbose) {
        display("  Test #", test.ind, ": ",deparse1(test))
      }
      ret = eval(test,ps$ps.baseenv)
      if (ret==FALSE) {
        return(inner.secure.check.chunk.return(FALSE))
      } else if (ret=="warning") {
        had.warning = TRUE
      } else {
        if (!is.null(ps$success.message)) {
          ps$success.log = c(ps$success.log,ps$success.message)
        }
      }
    }
  }

  if (had.warning) {
    return(inner.secure.check.chunk.return("warning"))
  } else {
    return(inner.secure.check.chunk.return(TRUE))
  }
}

inner.secure.check.chunk.return = function(ok, ps = get.ps()) {
  list(ok=ok,
    ps.fields = list(
      success.message=ps$success.message, failure.message=ps$failure.message, success.log=ps$success.log, e.ind = ps$e.ind, tdt.ind = ps$tdt.ind, task.env=ps$task.env, chunk.console.out = ps$chunk.console.out, chunk.ind = ps$chunk.ind
    )
  )
}


rtutor.eval.secure = function(..., envir=parent.frame(), timeout = ps$secure.eval.timeout, profile=ps$secure.eval.profile, ps=get.ps(), silent.check=TRUE, check.app.armor=FALSE) {

  if (check.app.armor) {
    # check if AppArmor is running. Otherwise don't eval 
    con =  try(RAppArmor::aa_getcon(verbose=!silent.check), silent = TRUE)
    check = is(con,"try-error")
    if (!check) check = !identical(con$mode,"enforce")
    if (check) {
      if (!RAppArmor::aa_is_enabled(verbose=!silent.check))
        stop("AppArmor is not enabled. User input is not evaluated.")
    }
  }
   
   
  #restore.point("rtutor.eval.secure")
  RAppArmor::eval.secure(...,envir=envir, timeout=timeout, profile=profile)
}

