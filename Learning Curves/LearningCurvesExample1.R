
# Bob Horton Microsoft: http://blog.revolutionanalytics.com/2015/09/why-big-data-learning-curves.html

sim_data <- function(N, noise_level=1){
  
  X1 <- sample(LETTERS[1:10], N, replace=TRUE)
  X2 <- sample(LETTERS[1:10], N, replace=TRUE)
  X3 <- sample(LETTERS[1:10], N, replace=TRUE)
  
  y <- 100 + ifelse(X1 == X2, 10, 0) + rnorm(N, sd=noise_level)
  
  data.frame(X1, X2, X3, y)
}

set.seed(123)
data <- sim_data(25000, noise=10)

rmse <- function(actual, predicted) sqrt( mean( (actual - predicted)^2 ))

run_learning_curve <- function(model_formula, data, vss=5000, num_tss=30, min_tss=1000){
  library(data.table)
  max_tss <- nrow(data) - vss
  tss_vector <- seq(min_tss, max_tss, length=num_tss)
  data.table::rbindlist( lapply (tss_vector, function(tss){
    vs_idx <- sample(1:nrow(data), vss)
    vs <- data[vs_idx,]
    
    ts_eligible <- setdiff(1:nrow(data), vs_idx)
    ts <- data[sample(ts_eligible, tss),]
    
    fit <- lm( model_formula, ts)
    training_error <- rmse(ts$y, predict(fit, ts))
    validation_error <- rmse(vs$y, predict(fit, vs))
    
    data.frame(tss=tss, 
               error_type = factor(c("training", "validation"), 
                                   levels=c("validation", "training")),
               error=c(training_error, validation_error))
  }) )
}

learning_curve <- run_learning_curve(y ~ X1*X2*X3, data)

library(ggplot2)
ggplot(learning_curve, aes(x=tss, y=error, linetype=error_type)) + 
  geom_line(size=1, col="blue") + xlab("training set size") + geom_hline(yintercept=10, linetype=3)

