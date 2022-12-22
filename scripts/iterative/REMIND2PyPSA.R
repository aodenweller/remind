# Dummy function to facilitate REMIND to PyPSA data exchange 
# Load package
library(remindPypsa)
library(gdx)
# Get arguments passed to script call
# 1: PyPSA directory, 2: Iteration
args <- commandArgs(trailingOnly = TRUE)
# Print status
print(paste("Starting REMIND2PyPSA.R in iteration", args[2], "using PyPSA directory", args[1]))
# Call function
remindPypsa::callREMIND2PyPSA(pyDir = args[1], iter = args[2])