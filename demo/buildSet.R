df.file <- system.file("extdata", "rs.data.csv", package="rENA")

codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");
codeNames_less = codeNames[1:4];

units_all_names = c("akash v","alexander b","amelia n","arden f","brandon l","cameron k","connor f","devin c","jimmy i","jordan l","joseph l","margaret n","peter p","robert z","steven z","tiffany x","abigail z","brandon f","brent p","cameron i","christina b","cormick u","daniel t","derek v","jackson p","keegan q","kiana k","luke u","madeline g","nathan d","nicholas l","nicholas n","ruzhen e","shane t","caitlyn y","justin y","samuel o","fletcher l","amirah u","carl b","christian x","kevin g","casey f","luis t","mitchell h","amalia x");

units_less_names = units_all_names[1:4];

  enadata = ENAdata$new(
    df,
    units.by = c("UserName","Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    code.names = codeNames, #_less,
    window.size = 1
  );
  enaset = ENAset$new(enadata, optim.method=do_optimization_2, inPar=F)$process()
