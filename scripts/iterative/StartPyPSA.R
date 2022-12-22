# Dummy function to start PyPSA
# Load package
library(remindPypsa)
# Get arguments passed to script call
# 1: PyPSA directory, 2: Iteration
args <- commandArgs(trailingOnly = TRUE)
# Print status
print(paste("Starting PyPSA in iteration", args[2], "using PyPSA directory", args[1]))
# Call function
remindPypsa::startPyPSA(pyDir = args[1], iter = args[2])