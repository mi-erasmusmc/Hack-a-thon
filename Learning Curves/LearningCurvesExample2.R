# Bob Horton Microsoft: http://blog.revolutionanalytics.com/2016/03/learning-from-learning-curves.html

# install.packages("foreach")
# install.packages("doParallel")
# install.packages("dplyr")
# install.packages("tidyr")

# Start by simulating a dataset:
  
  sim_data <- function(N, num_inputs=8, input_cardinality=10){
    inputs <- rep(input_cardinality, num_inputs)
    names(inputs) <- paste0("X", seq_along(inputs))
    
    as.data.frame(lapply (inputs, function(cardinality)
      sample(LETTERS[1:cardinality], N, replace=TRUE)))
  }
  
#  The input columns are named X1, X2, etc.; these are all categorical variables with single 
#  capital letters representing the different categories. Cardinality is the number of possible 
#  values in the column; our default cardinality of 10 means we sample from the capital letters A through J.
#  Next we’ll add an outcome variable (y); it has a base level of 100, but if the values in the first 
#  two X variables are equal, this is increased by 10. On top of this we add some normally distributed noise.
  
  set.seed(123)
  data <- sim_data(3e4, input_cardinality=10)
  noise <- 2
  data <- transform(data, y = ifelse(X1 == X2, 110, 100) + 
                      rnorm(nrow(data), sd=noise))
  
# With linear models, we handle an interaction between two categorical variables by 
# adding an interaction term; the number of possibilities in this interaction term is 
# basically the product of the cardinalities. In this simulated data set, only the first 
# two columns affect the outcome, and the other input columns don’t contain any useful information. 
# We’ll use it to demonstrate how adding non-informative variables affects overfitting and training
# set size requirements.
# The root mean squared error of the predictions is used as the error function because RMSE is 
# essentially the same as standard deviation. No model should be able to make predictions with a 
# root mean squared error less than the standard deviation of the random noise we added.
  
  rmse <- function(actual, predicted) sqrt( mean( (actual - predicted)^2 ))
  
# The cross-validation function trains a model using the supplied formula and 
# modeling function, then tests its performance on a held-out test set. 
# The training set will be sampled from the data available for training; 
# to use approximately a 10% sample of the training data, set prob_train to 0.1.
  
  cross_validate <-
    function(model_formula,
             fit_function,
             error_function,
             validation_set,
             training_data,
             prob_train = 1) {
      training_set <-
        training_data[runif(nrow(training_data)) < prob_train, ]
      tss <- nrow(training_set)
      
      outcome_var <- as.character(model_formula[[2]])
      
      fit <- fit_function(model_formula, training_set)
      
      training_error <- error_function(training_set[[outcome_var]],
                                       predict(fit, training_set))
      validation_error <- error_function(validation_set[[outcome_var]],
                                         predict(fit, validation_set))
      
      data.frame(
        tss = tss,
        formula = deparse(model_formula),
        training = training_error,
        validation = validation_error,
        stringsAsFactors = FALSE
      )
    }
  
  # Construct a family of formulas, then use expand_grid to make a dataframe with 
  # all the combinations of formulas and sampling probabilities:
    
  generate_formula <- function(num_inputs, degree=2, outcome="y"){
      inputs <- paste0("X", 1:num_inputs)
      rhs <- paste0("(", paste(inputs, collapse=" + "), ") ^ ", degree)
      paste(outcome, rhs, sep=" ~ ")
  }
  formulae <- lapply(2:(ncol(data) - 1), generate_formula)
  prob <- 2^(seq(0, -6, by=-0.5))
  parameter_table <- expand.grid(formula=formulae, 
                                 sampling_probability=prob, 
                                 stringsAsFactors=FALSE)
  
  #Separate the training and validation data:
    
  validation_fraction <- 0.25
  in_validation_set <- runif(nrow(data)) < validation_fraction
  vset <- data[in_validation_set,]
  tdata <- data[!in_validation_set,]
  run_param_row <- function(i){
    param <- parameter_table[i,]
    cross_validate(formula(param$formula[[1]]), lm, rmse, 
                   vset, tdata, param$sampling_probability[[1]])
  }
  # Now call the cross-validate function on each row of the parameter table. 
  # The foreach package makes it easy to process these jobs in parallel:
    
  library(foreach)
  library(doParallel)
  registerDoParallel() # automatically manages cluster
  learning_curve_results <- foreach(i=1:nrow(parameter_table)) %dopar% run_param_row(i)
  learning_curve_table <- data.table::rbindlist(learning_curve_results)
  
  # The rbindlist() function from the data.table package puts the results 
  # together into a single data frame; this is both cleaner and dramatically
  # faster than the old do.call("rbind", ...) approach (though we’re just 
  # combining a small number of rows, so speed is not an issue here).
  
  # Now plot the results. Since we’ll do another plot later, I’ll wrap the 
  # plotting code in a function to make it more reusable.
  
  plot_learning_curve <- function(lct, title, base_error, plot_training_error=TRUE, ...){
    library(dplyr)
    library(tidyr)
    library(ggplot2)
    
    lct_long <- lct %>% gather(type, error, -tss, -formula)
    
    lct_long$type <- relevel(as.factor(lct_long$type), "validation")
    
    plot_me <- if (plot_training_error) lct_long else lct_long[lct_long$type=="validation",]
    
    ggplot(plot_me, aes(x=log10(tss), y=error, col=formula, linetype=type)) + 
      ggtitle(title) + geom_hline(yintercept=base_error, linetype=2) + 
      geom_line(size=1) + xlab("log10(training set size)") + coord_cartesian(...)
  }
  plot_learning_curve(learning_curve_table, title="Extraneous variables are distracting", 
                      base_error=noise, ylim=c(0,4))