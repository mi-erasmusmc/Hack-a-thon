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

# Learning curve example
source("LearningCurvesExample2.R")