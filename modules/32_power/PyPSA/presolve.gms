*** |  (C) 2006-2022 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/presolve.gms

***------------------------------------------------------------
***                  Presolve copied from IntC
***------------------------------------------------------------

*** calculation of SE electricity price (useful for internal use and reporting purposes)
pm_SEPrice(t,regi,entySE)$(abs (qm_budget.m(t,regi)) gt sm_eps AND sameas(entySE,"seel")) = 
       q32_balSe.m(t,regi,entySE) / qm_budget.m(t,regi);

***------------------------------------------------------------
***                  PyPSA coupling (copied from postsolve for testing)
***------------------------------------------------------------

$ontext
if ( (ord(iteration) ge cm_startIter_PyPSA) and (mod(ord(iteration), 3) eq 0),
  !! Export REMIND data for PyPSA
  Execute_Unload "/p/tmp/adrianod/pypsa-eur/REMIND2PyPSA.gdx", vm_prodSe;

  !! Run REMIND2PyPSA.R
  Execute "Rscript -e '/p/tmp/adrianod/pypsa-eur/REMIND2PyPSA.R RM_Py_test'";  !! Pass run name as parameter

  !! Run PyPSA
  put "Running PyPSA in iteration ", round(ord(iteration))
  Put_utility 'Exec' / '/p/tmp/adrianod/pypsa-eur/StartPyPSA.sh' round(ord(iteration)) RM_Py_test;  !! Pass iteration and run name as parameter

  !! Run PyPSA2REMIND.R
  !!Execute "Rscript -e '/p/tmp/adrianod/pypsa-eur/PyPSA2REMIND.R'";

  !! Import PyPSA data for REMIND
  !!Execute_Loadpoint "PyPSA2REMIND.gdx";

  !! Assign values from PyPSA to REMIND

);
$offtext

*** EOF ./modules/32_power/PyPSA/presolve.gms
