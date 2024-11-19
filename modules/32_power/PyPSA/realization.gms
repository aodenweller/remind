*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/realization.gms

*' @description  
*'
*'The `PyPSA` realization implements an iterative soft-link to Python for Power System Analysis based on the IntC realisation.
*'
*'A detailed description will follow.
*'
*' @authors Adrian Odenweller, Johannes Hampp, Chris Gong, Falko Ueckerdt, Robert Pietzcker

*####################### R SECTION START (PHASES) ##############################
$Ifi "%phase%" == "sets" $include "./modules/32_power/PyPSA/sets.gms"
$Ifi "%phase%" == "declarations" $include "./modules/32_power/PyPSA/declarations.gms"
$Ifi "%phase%" == "datainput" $include "./modules/32_power/PyPSA/datainput.gms"
$Ifi "%phase%" == "equations" $include "./modules/32_power/PyPSA/equations.gms"
$Ifi "%phase%" == "preloop" $include "./modules/32_power/PyPSA/preloop.gms"
$Ifi "%phase%" == "bounds" $include "./modules/32_power/PyPSA/bounds.gms"
$Ifi "%phase%" == "presolve" $include "./modules/32_power/PyPSA/presolve.gms"
$Ifi "%phase%" == "postsolve" $include "./modules/32_power/PyPSA/postsolve.gms"
$Ifi "%phase%" == "output" $include "./modules/32_power/PyPSA/output.gms"
*######################## R SECTION END (PHASES) ###############################

*** EOF ./modules/32_power/PyPSA/realization.gms
