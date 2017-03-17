
install.packages("devtools")
library(devtools)
install_github("ohdsi/OhdsiRTools") 
install_github("ohdsi/SqlRender")
install_github("ohdsi/DatabaseConnector")
install_github("ohdsi/Cyclops")
install_github("ohdsi/FeatureExtraction") 
install_github("ohdsi/BigKnn")
install_github("ohdsi/PatientLevelPrediction")
install_github("ohdsi/OhdsiSharing")
install_github("ohdsi/StudyProtocolSandbox/LargeScalePrediction")

library(LargeScalePrediction)
options('fftempdir' = '/Users/Shared/tempff')


dbms <- "sql server"
user <- ""
password <- ""
server <- "emif.database.windows.net"
port <- 1433
extraSettings <- "database=SYNPUF;lencrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
connectionDetails <- createConnectionDetails(dbms = dbms,
                                             user = user,
                                             password = password,
                                             server = server,
                                             port = port,
                                             extraSettings = extraSettings)

cdmDatabaseSchema <- "SYNPUF.dbo"
workDatabaseSchema <- "SYNPUF.results"
studyCohortTable <- "LargeScalePrediction"
workFolder <- "/Users/Shared/LargeScalePrediction"

fetchAllDataFromServer(connectionDetails = connectionDetails,
                       cdmDatabaseSchema = cdmDatabaseSchema,
                       workDatabaseSchema = workDatabaseSchema,
                       studyCohortTable = studyCohortTable,
                       workFolder = workFolder)