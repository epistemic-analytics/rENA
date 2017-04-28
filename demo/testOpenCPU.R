library("httr")
library("stringr")
library("microbenchmark")

base = "http://34.209.246.198/ocpu"
#base = "http://localhost:4075/ocpu"

file.uploaded = POST(url=paste0(base,"/library/utils/R/read.csv"),
 body=list(file=upload_file("./inst/extdata/newcombnonbin2r.csv", "text/csv"))
)
file.uploaded.res = content(file.uploaded, "text");
file.uploaded.ses = str_match(file.uploaded.res, "/tmp/([^/]*)/")[2]

data.accumulated = POST(url=paste0(base,"/library/rENA/R/ena.accumulate.data"),
  body=list(
    "file" = file.uploaded.ses,
    "codeNames" = "c('P1r','P2r','P3r','P4r','P5r','P6r','P7r','P8r','P9r','P10r','P11r','P12r','P13r','P14r','P15r','P16r','P17r','P1s','P2s','P3s','P4s','P5s','P6s','P7s','P8s','P9s','P10s','P11s','P12s','P13s','P14s','P15s','P16s','P17s')",
    "unitsBy" = "c('week','send')",
    "conversationsBy" = "c('stanza')",
    "windowSize" = 1
  )
)
data.accumulated.res = content(data.accumulated, "text");
data.accumulated.ses = str_match(data.accumulated.res, "/tmp/([^/]*)/")[2];

data.bm = microbenchmark(
  data.set = POST(url=paste0(base,"/library/rENA/R/ena.make.set"),
    body=list(
      "enaData"=data.accumulated.ses,
      "inPar"="true"
    )
  )
, times = 1)
print(data.bm)
