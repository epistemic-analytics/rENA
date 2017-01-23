if(ls(pattern="gotSet") != "gotSet") {
  print("Creating the GoT set.");
  source('./R/buildSet_got.R');
}
runApp("./demo/shiny", port=7705, launch.browser = F)
