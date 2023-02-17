# Execute the REMIND-PyPSA coupling

# Load packages
library(remindPypsa)
library(gdx)

# Get arguments passed to Rscript call
# 1: PyPSA directory, 2: Iteration
args <- commandArgs(trailingOnly = TRUE)

# Step 1: Call REMIND2PyPSA.R
cat("Calling REMIND2PyPSA.R in iteration", args[2], "\n")
remindPypsa::callREMIND2PyPSA(pyDir = args[1], iter = args[2])

# Step 2: Call startPyPSA.R
cat("Starting PyPSA in iteration", args[2], "\n")
remindPypsa::startPyPSA(pyDir = args[1], iter = args[2])

# Step 3: Call PyPSA2REMIND.R
cat("Calling PyPSA2REMIND.R in iteration", args[2], "\n")
remindPypsa::callPyPSA2REMIND(pyDir = args[1], iter = args[2])
