# first install all the packages you need for connection
install.packages("devtools")
library(devtools)
install_github("ohdsi/OhdsiRTools") 
install_github("ohdsi/SqlRender")
install_github("ohdsi/DatabaseConnector")

library(DatabaseConnector)
library(SqlRender)

# connection details for the aws instance (password will be provided)
dbms <- "redshift"
user <- "synpuf_training"
password <- password

# for the 1% sample:
server <- "ohdsi.cxmbbsphpllo.us-east-1.redshift.amazonaws.com/synpuf1pct"
port <- 5439
connectionDetails <- createConnectionDetails(dbms = dbms,
                                             user = user,
                                             password = password,
                                             server = server,
                                             port = port)
connection <- connect(connectionDetails)

# test your connection:
sql <- translateSql("select * from cdm.person", targetDialect = connectionDetails$dbms)$sql
result <- querySql(connection, sql)

# now load featureExtraction and PatientLevelPrediction
install_github("ohdsi/FeatureExtraction") 
install.packages("drat")
drat::addRepo("OHDSI")
install.packages("PatientLevelPrediction")

# settings:
databaseSchema <- 'cdm'
targetSchema <- 'scratch'
targetId <- 1
outcomeId <- 2

# target population is people with visit in the database (first visit is cohort start date)
# outcome is people with Major depression

#======================== ALREADY RAN THIS TO CREATE COHORTS =========================
# create target cohorts:
#sql_table <- "create table @target_database_schema.ftf_cohort(cohort_definition_id int, subject_id bigint, cohort_start_date date, cohort_end_date date);"
#sql <- renderSql(sql_table, cdm_database_schema=databaseSchema,
#                 target_database_schema=targetSchema,
#                 target_cohort_table='ftf_cohort',
#                 target_cohort_id=targetId)$sql
#sql <- translateSql(sql, targetDialect = connectionDetails$dbms)$sql
#executeSql(connection, sql)
#
#sql <- renderSql(sql_target, cdm_database_schema=databaseSchema,
#                 target_database_schema=targetSchema,
#                 target_cohort_table='ftf_cohort',
#                 target_cohort_id=targetId)$sql
#sql <- translateSql(sql, targetDialect = connectionDetails$dbms)$sql
#executeSql(connection, sql)
#
#sql <- renderSql(sql_outcome, cdm_database_schema=databaseSchema,
#                 target_database_schema=targetSchema,
#                 target_cohort_table='ftf_cohort',
#                 target_cohort_id=outcomeId)$sql
#sql <- translateSql(sql, targetDialect = connectionDetails$dbms)$sql
#executeSql(connection, sql)
#=======================================================================================

# covariate settings:
# there are lots of default features, run ?FeatureExtraction::createCovariateSettings to find about them
covSettings <- FeatureExtraction::createCovariateSettings( useCovariateDemographics = TRUE,
                                                           useCovariateDemographicsGender = T,
                                                           useCovariateDemographicsAge = T,
                                                           useCovariateDemographicsMonth = T,
                                                           useCovariateConditionEra = T,
                                                           useCovariateConditionEraEver = T,
                                                           useCovariateDrugEra = T,
                                                           useCovariateDrugEraEver = T,
                                                           useCovariateProcedureOccurrence = T,
                                                           useCovariateProcedureOccurrence365d = T,
                                                           useCovariateMeasurement = T,
                                                           useCovariateMeasurement365d = T,
                                                           useCovariateObservation = T,
                                                           useCovariateObservation365d = T,
                                                           deleteCovariatesSmallCount = 20)

# extract the data: 
plpData <- PatientLevelPrediction::getPlpData(connectionDetails, cdmDatabaseSchema=databaseSchema,
                                              cohortId=targetId, 
                                              outcomeIds=outcomeId, 
                                              outcomeDatabaseSchema = targetSchema,
                                              outcomeTable = 'ftf_cohort',
                                              cohortDatabaseSchema = targetSchema,
                                              cohortTable = 'ftf_cohort',
                                              cdmVersion=5,
                                              washoutPeriod=365,
                                              covariateSettings=covSettings)

# define the prediction problem
# in this example, predict the outcome within 1 year (riskWindow settings), 
# remove people without the outcome within prior 9999 days 
# 
population <- PatientLevelPrediction::createStudyPopulation(plpData, 
                                                            outcomeId = outcomeId, # state outcome to be predicted
                                                            firstExposureOnly = T, # only use first date for each target popualtion person 
                                                            washoutPeriod = 365, # remove people with less than 365 days prior observation
                                                            removeSubjectsWithPriorOutcome = T, # remove people who have had the outcome beforehand
                                                            priorOutcomeLookback=9999, # how long beforehand to look back for outcome
                                                            riskWindowStart = 1, # when to start predicting the outcome (days from cohort_start_date)
                                                            addExposureDaysToStart = F, # when set to T then the outcome is predicted from cohort_end_date+riskWindowsStart rather then cohort_start_date+riskWindowsStart 
                                                            riskWindowEnd = 365*1, # when to stop predicting the outcome (days from cohort_start_date)
                                                            addExposureDaysToEnd=F,# when set to T then the outcome is predicted until cohort_end_date+riskWindowsEnd rather then cohort_start_date+riskWindowsEnd 
                                                            requireTimeAtRisk = T,# remove people who get censored before having outcome
                                                            minTimeAtRisk = 365*1-1 # people are censored if they have no outcome and are observed less than this number of days after cohort start
                                                             )

# train the model and get internal validation
lr_model <- PatientLevelPrediction::setLassoLogisticRegression()
lr_results <- PatientLevelPrediction::RunPlp(population, plpData, 
                                             modelSettings = lr_model,
                                             testSplit='person',
                                             testFraction=0.25,
                                             nfold=10) 

# Test benchmark for depression; 71.44

# view the performance
PatientLevelPrediction::plotSparseRoc(lr_results$performanceEvaluation)
PatientLevelPrediction::plotSparseCalibration(lr_results$performanceEvaluation)
PatientLevelPrediction::plotSparseCalibration2(lr_results$performanceEvaluation)
PatientLevelPrediction::plotDemographicSummary(lr_results$performanceEvaluation)


# TASK: GET THE BEST MODEL USING NOVEL FEATURES/CLASSIFIERS

# custom covariates
# see: https://raw.githubusercontent.com/OHDSI/FeatureExtraction/master/inst/doc/CreatingCustomCovariateBuilders.pdf

# custom classifier: create the R file like 
# - R classifier: https://github.com/OHDSI/PatientLevelPrediction/blob/master/R/GradientBoostingMachine.R
# - python classifier: https://github.com/OHDSI/PatientLevelPrediction/blob/master/R/RandomForest.R
# ! dont forget to add to the prediction file: https://github.com/OHDSI/PatientLevelPrediction/blob/master/R/Predict.R

