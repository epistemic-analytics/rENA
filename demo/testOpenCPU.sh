export CSV=`curl http://54.71.117.56/ocpu/library/utils/R/read.csv -F "file=@/Users/clmarquart/Workspaces/RStudio2/rENA/inst/extdata/newcombnonbin2r.csv"`

export CSV_SESSION=$(echo $CSV | perl -n -e'/tmp\/([^\/]*)\// && print $1')

echo $CSV_SESSION
