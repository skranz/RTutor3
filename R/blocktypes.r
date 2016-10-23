
# blocks specified in RTutor
armd.block.types.df = function(...) {
  restore.point("armd.block.types.df")

  types = c(
    "chunk","quiz","award",
    "preknit","precompute",
    "show","notest","show_notest","hint","test","test_args",
    "rmdform"
  )
  widgets = c("chunk","quiz","award","rmdform")
  parent.types = c("chunk","precompute","preknit","award")
  container.types = c("award")
  n = length(types)
  bt.df = data_frame(type=types, package="RTutor3", is.widget=types %in% widgets, parse.inner.blocks = (type!="chunk"), remove.inner.blocks=types=="rmdform", is.parent=types %in% parent.types, is.container = types %in% container.types, dot.level=0, arg.li = vector("list",n))
  
  bt.df
}
