RS.data = read.csv(system.file(package = "rENA", 'extdata/rs.data.csv'), stringsAsFactors = FALSE)
RS.data$text <- gsub(x = RS.data$text, pattern = "\\b[^@]*@[A-Za-z0-9.-]+\\.[a-z0-9]+\\b", replacement = "[EMAIL]", perl = T);
usethis::use_data(RS.data, overwrite = TRUE)

# ^\(?([0-9]{3})\)?[-.*]?([0-9]{3})[-.*]?([0-9]{4})$
