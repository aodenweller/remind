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
***                  PyPSA postsolve copy for testing only
***------------------------------------------------------------

if ( (iteration.val eq 1),
  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload 'REMIND2PyPSA_i' iteration.val:0:0 '.gdx', vm_prodSe;

  !! Run REMIND2PyPSA.R
  !! This script uses output data from REMIND (REMIND2PyPSA.gdx) to create input data for PyPSA (multiple files)
  Put_utility 'Exec' / 'Rscript REMIND2PyPSA.R %c32_pypsa_dir% ' iteration.val:0:0;

  !! Run PyPSA
  !! Pass iteration and run name as parameter
  Put_utility 'Exec' / 'Rscript StartPyPSA.R %c32_pypsa_dir% ' iteration.val:0:0;

  !! Run PyPSA2REMIND.R
  !! This script uses output data from PyPSA (multiple files) to create input data for REMIND (PyPSA2REMIND.gdx)
  Put_utility 'Exec' / 'Rscript PyPSA2REMIND.R %c32_pypsa_dir% ' iteration.val:0:0;

  !! Import PyPSA data for REMIND
  Execute_Loadpoint 'PyPSA2REMIND_i' iteration.val:0:0 '.gdx', p32_Py2RM=PyPSA2REMIND;

  !! Capacity factor
  loop (tePyMapDisp32(tePyImp32,tePy32),
    pm_cf(tPy32,regPy32,tePy32) =
      p32_Py2RM(tPy32,regPy32,tePyImp32,"capfac")
  );

);

*** EOF ./modules/32_power/PyPSA/presolve.gms
