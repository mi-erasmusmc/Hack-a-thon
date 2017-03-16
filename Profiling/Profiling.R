# Demo of using profiling to find the bottleneck in code performance
# It would be very informative to use this on our PLP package
# during the Hack-a-Thon so we can focus on the most important parts
# to improve the speed of the package.

# See https://rstudio.github.io/profvis/ for more information

# install.packages("profvis")

# An example
library(profvis)

profvis({
  data(diamonds, package = "ggplot2")
  
  plot(price ~ carat, data = diamonds)
  m <- lm(price ~ carat, data = diamonds)
  abline(m, col = "red")
})


# You can also use proftools

# library(devtools)
# install_github("OHDSI/PatientLevelPrediction", args="--with-keep.source")
# install.packages("proftools")
# install.packages("gWidgets2")
# install.packages("gWidgets2RGtk2")
# install_github("ltierney/Rpkg-proftools-GUI")

library(LargeScalePrediction)
library(futile.logger)

library(proftools)
library(gWidgets2)
library(gWidgets2RGtk2)
library(proftoolsGUI)

# Example of loading a model and profile the evaluation part (use your own folders!)
plpData <- loadPlpData("./data")
amiModel <- loadPlpModel("./models/lrmodels/2557/20160913025439/savedModel")

oid <- 2557
workFolder <- "./"
population <- read.csv(file.path(workFolder, 'Populations',oid))[,-1]
attr(population, "metaData")$cohortId <- plpData$metaData$call$cohortId
attr(population, "metaData")$outcomeId <- oid

prediction <- ftry(predictPlp(plpModel = amiModel, population = population, plpData = plpData, index = NULL), 
                   finally = flog.trace('Done.'))

pd <- profileExpr({performance.train <- evaluatePlp(prediction, plpData)})

head(funSummary(pd), 50)
hotPaths(pd, total.pct = 10.0)
