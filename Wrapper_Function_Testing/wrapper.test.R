### Test Wrapper Function ###

rm(list=ls())

source('~/rENA/R/ena.wrapper.R')

# With RSData #

data(RS.data)

#add warning message for using a grouping var not in units or metadata
#add conditional for plotting points and means


codes = c('Data',
          'Technical.Constraints',
          'Performance.Parameters',
          'Client.and.Consultant.Requests',
          'Design.Reasoning',
          'Collaboration')

data = RS.data
units = c("UserName","Condition", "GroupName")
convo = c("Condition","GroupName")
meta = c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post","C.Change")
window.type = "MovingStanzaWindow"
window.size = 5
group1 = "FirstGame"
group2 = "SecondGame"
groupCol = "Condition"

rs = ena.wrapper(data = data,
                     codes = codes,
                     units = units,
                     conversations = convo,
                     metadata = meta,
                     windowType = window.type,
                     windowSize = window.size,
                     groupCol = groupCol,
                     group1 = group1,
                     group2 = group2)



# With Navy Data #

data = read.csv("~/rENA/Wrapper_Function_Testing/TADMUSCoded.csv",stringsAsFactors = FALSE)

codes = c("SeekingInformation",
          "DetectIdentify",
          "TrackBehavior",
          "StatusUpdate",
          "AssessmentPrioritization",
          "DefensiveOrders",
          "DeterrentOrders",
          "Recommendation")

units = c("Team","Speaker")
convo = c("Team","Scenario")
meta = c("COND","MacroRole")
window.type = "MovingStanzaWindow"
window.size = 5
group1 = "Experimental"
group2 = "Control"
groupCol = "COND"

navy = ena.wrapper(data = data,
                codes = codes,
                units = units,
                conversations = convo,
                metadata = meta,
                windowType = window.type,
                windowSize = window.size,
                groupCol = groupCol,
                group1 = group1,
                group2 = group2)
