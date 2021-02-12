codeNames = c("Data","Technical.Constraints","Performance.Parameters","Client.and.Consultant.Requests","Design.Reasoning","Collaboration")
accum = ena.accumulate.data(
  units = RS.data[,c("Condition","UserName")],
  conversation = RS.data[,c("Condition","GroupName")],
  metadata = RS.data[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post","C.Change")],
  codes = RS.data[,codeNames],
  model = "EndPoint",
  window.size.back = 4
);
### Set 3 zero networks for units 1, 3, 5
accum$connection.counts[1,8:22]=0
accum$connection.counts[3,8:22]=0
accum$connection.counts[5,8:22]=0
### create ENA set WITHOUT center alignment
set_F = ena.make.set(
  enadata = accum,
  rotation.by = ena.rotate.by.mean,
  rotation.params = list(FirstGame=accum$meta.data$Condition=="FirstGame",
                         SecondGame=accum$meta.data$Condition=="SecondGame"),
  center.align.to.origin = F
);
### We see that the points for the zero network units 1, 3, 5 are the same non-zero point
View(set_F$points[1:5,8:22])
### And we see that the centroids of the zero network units 1, 3, 5 are zero.
View(set_F$model$centroids[1:5,])
### But the mean centroids is not zero
mean_centroid_F = colMeans(set_F$model$centroids[,2:ncol(set_F$model$centroids)])
View(mean_centroid_F)

### create ENA set WITH center alignment
set_T = ena.make.set(
  enadata = accum,
  rotation.by = ena.rotate.by.mean,
  rotation.params = list(FirstGame=accum$meta.data$Condition=="FirstGame",
                         SecondGame=accum$meta.data$Condition=="SecondGame"),
  center.align.to.origin = T
);
### We see that the points for the zero network units 1, 3, 5 are now at origin
View(set_T$points[1:5,8:22])
### And we see that the centroids of the zero network units 1, 3, 5 are also zero.
View(set_T$model$centroids[1:5,])
### And the mean centroid is also zero
mean_centroid_T = colMeans(set_T$model$centroids[,2:ncol(set_T$model$centroids)])
View(mean_centroid_T)

