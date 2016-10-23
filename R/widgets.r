
rtutor.parse.widget = function(bi, ps, opts=ps$opts) {
  restore.point("rtutor.parse.widget")
  
  bdf = ps$bdf; br = bdf[bi,];
  type = br$type
  
  # special treatment for chunks and awards
  # in order not to change old code too much
  if (type=="chunk") {
    rtutor.parse.chunk(bi,ps,opts)
    return()
  } else if (type=="award") {
    rtutor.parse.award(bi=bi, ps=ps)
    return()
  }
  
  Wid = ps$Widgets[[type]]
  
  args = parse.block.args(arg.str = br$arg.str)
  if (!is.null(args$name)) ps$bdf$name[[bi]] = args$name
  wid = Wid$parse.fun(
    block.txt = ps$txt[br$start:br$end],
    inner.txt = ps$txt[(br$start+1):(br$end-1)],
    id = paste0(type,"__",bi),
    args = args,
    type = type,
    bdf=bdf,
    bi = bi,
    ps = ps
  )
  if (!is.null(Wid$ui.fun)) {
    # the widget will be put inside a container
    ps$bdf$is.container[[bi]] = TRUE
    set.container.div.and.output(bi,ps)
  }

  if (isTRUE(Wid$is.task)) {
    ps$bdf$is.task[[bi]] = Wid$is.task
    wid$task.ind = sum(ps$bdf$is.task[1:bi])
    
    create.bi.task.env.info(bi=bi,ps=ps,need.task.env = isTRUE(Wid$need.task.env),change.task.env = isTRUE(Wid$change.task.env),args=list(optional = TRUE),presolve.task = opts$presolve, opts=opts)  

  }
  ps$bdf$obj[[bi]] = list(wid=wid)
  
  
  return()
}



# will be called from parse.armd
rtutor.init.widgets = function(ps) {
  restore.point("rtutor.init.widgets")
  
  bdf = ps$bdf
  restore.point("rtutor.init.widgets")
  
  n = NROW(ps$bdf)
  ps$bdf = mutate(bdf,
    is.task = FALSE,task.ind = 0,
    task.line = NA_character_,
    task.in = vector("list", n),
    task.listeners = vector("list",n),
    
    # These arguments deal with task.envs
    need.task.env = FALSE,
    change.task.env = FALSE,
    presolve.task = ps$opts$presolve
  )
  bdf = ps$bdf
  widgets = unique(bdf$type[bdf$is.widget])

  # currently still
  # special treatment for chunks and awards
  widgets = setdiff(widgets,c("chunk","award"))
  
  Widgets = lapply(widgets, function(widget) {
    pkg = get.bt(widget,ps)$package
    call = parse(text=paste0(pkg,":::rtutor.widget.",widget,"()"))
    Widget = eval(call)
  })
  names(Widgets) = widgets
  ps$Widgets=Widgets
  ps$env = new.env(parent=ps$init.env)

}



render.rtutor.widget = function(ps, bi,  ts = get.ts(bi=bi), init.handlers=TRUE) {
  restore.point("render.rtutor.widget")
  cat("\n******************************************")
  cat("\nrender.rtutor.widget")

  wid = ts$wid
  type = ps$bdf$type[[bi]]
  Wid = ps$Widgets[[type]]
  ui = Wid$ui.fun(ts=ts)
  output.id = ps$bdf$output.id[[bi]]  
  setUI(output.id, ui)
  dsetUI(output.id, ui)
  if (init.handlers)
    Wid$init.handlers(wid=wid,ts=ts,bi=bi)
  #cat("render add on not yet implemented.")
}

update.widget = function(id, bi = which(ps$bdf$id==id),ps=get.ps(),...) {
  restore.point("update.widget")
  cat("\n++++++++++++++++++++++++++++++++++++++++++")
  cat("\nupdate.widget")

  Wid = get.Widget(bi=bi)
  wid = get.widget(bi=bi)
  if (!is.null(Wid[["update"]]))
    Wid$update(wid=wid,bi=bi,...)
  render.rtutor.widget(bi=bi, ps=ps, init.handlers = FALSE)
}

get.widget = function(bi, ps=get.ps()) {
  ps$bdf$obj[[bi]]$wid
}

make.widgets.list = function(widgets="quiz") {
   li = lapply(widgets, function(widget) {
     fun = paste0("rtutor.widget.",widget)
     do.call(fun,list())
   })
   names(li) = widgets
  li
}

get.Widget = function(bi=NULL,type=ps$bdf$type[[bi]], ps=get.ps()) {
  ps$Widgets[[type]]
}

check.Widget = function(Wid) {
  restore.point("check.Widget")
  check.Widget.field(c("type"),type="")  
  type = Wid$type
  check.Widget.field(c("package","is.task"),type=type)   
  check.Widget.function("parse.fun",type)
  if (Wid$is.task) {
    check.Widget.function(c("init.task.state","init.handlers", "ui.fun"),type)
    check.Widget.field(c("need.task.env","change.task.env"),type=type) 
  }
  
  
  
}

check.Widget.function = function(fun.name, type="") {
  for (fun in fun.name) {
    if (is.null(Wid[[fun]])) {
      stop(paste0("The widget ", type, " has not defined the function ", fun))
    }
  }
}
check.Widget.field = function(fields, type="") {
  for (field in fields) {
    if (is.null(Wid[[field]])) {
      stop(paste0("The widget ", type, " has not defined the required field ", field))
    }
  }
  
}

get.yaml.block.args = function(bi,ps) {
  restore.point("get.yaml.block.args")

  args = parse.block.args(arg.str = ps$bdf$arg.str[[bi]])
  yaml = get.bi.ps.str(bi,ps)
  if (!is.null(yaml)) {
    yaml.arg = yaml.load(paste0(yaml,collapse="\n"))
    args[names(yaml.arg)] = yaml.arg
  }
  args
}
