dataf = fread("./data/GOTENA_EGOCENTRIC-1-16-17.csv")

oldCols = colnames(dataf)
oldCols[oldCols == "uniqueID"] = "unique_id";
oldCols[oldCols == "excerptID"] = "excerpt_id";
oldCols[oldCols == "house"] = "house_bak";
oldCols[oldCols == "house_2"] = "house";
oldCols = gsub("\\.", "_", x = oldCols)
oldCols
colnames(dataf) <- oldCols;
dataf[dataf$house == "Other"]$house = "Extra";
dataf$character = gsub("\\.", "_", x = dataf$character, perl=T)

write.csv(dataf, file="./data/got-ena-ego-v1.csv");
