*** |  (C) 2006-2022 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/postsolve.gms

***------------------------------------------------------------
***                  Postsolve copied from IntC
***------------------------------------------------------------

*** calculation of SE electricity price (useful for internal use and reporting purposes)
pm_SEPrice(ttot,regi,entySE)$(abs (qm_budget.m(ttot,regi)) gt sm_eps AND sameas(entySE,"seel")) = 
       q32_balSe.m(ttot,regi,entySE) / qm_budget.m(ttot,regi);

loop(t,
  loop(regi,
    loop(pe2se(enty,enty2,te),
      if ( ( vm_capFac.l(t,regi,te) < (0.999 * vm_capFac.up(t,regi,te) ) ),
        o32_dispatchDownPe2se(t,regi,te) = round ( 100 * (vm_capFac.up(t,regi,te) - vm_capFac.l(t,regi,te) ) / (vm_capFac.up(t,regi,te) + 1e-10) );
      );
    );
  );
);

***------------------------------------------------------------
***                  PyPSA coupling
***------------------------------------------------------------

if ( (iteration.val ge c32_startIter_PyPSA) and (mod(iteration.val, 5) eq 0),
  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload 'REMIND2PyPSA.gdx', vm_prodSe;
  Put_utility 'shell' / "cp REMIND2PyPSA.gdx REMIND2PyPSA_i" iteration.val:0:0 '.gdx';

  !! Run StartREMINDPyPSA.R (copied from scripts/iterative)
  !! This executes three steps, using the pik-piam/remindPypsa package
  !! 1) Exchange data from REMIND to PyPSA
  !! 2) Execute PyPSA
  !! 3) Exchange data from PyPSA to REMIND
  Put_utility 'Exec' / 'Rscript StartREMINDPyPSA.R %c32_pypsa_dir% ' iteration.val:0:0;

  !! Import PyPSA data for REMIND (PyPSA2REMIND.gdx)
  Put_utility 'shell' / 'cp PyPSA2REMIND_i' iteration.val:0:0 '.gdx PyPSA2REMIND.gdx';
  Execute_Loadpoint 'PyPSA2REMIND.gdx', p32_Py2RM=PyPSA2REMIND;

  !! Capacity factor
  loop (tePyMapDisp32(tePyImp32,tePy32),
    pm_cf(tPy32,regPy32,tePy32) =
      p32_Py2RM(tPy32,regPy32,tePyImp32,"capfac")
  );

);

*** EOF ./modules/32_power/PyPSA/postsolve.gms

