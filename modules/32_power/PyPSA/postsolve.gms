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

if ( (iteration.val ge c32_startIter_PyPSA) and (mod(iteration.val - c32_startIter_PyPSA, 1) eq 0),

  !! Calculate parameters that will be passed to REMIND
  !! Discount rate
  !! TODO: Already exists somewhere else?
  p32_PyDisrate(ttot,all_regi)$(tPy32s(ttot) AND regPy32(all_regi))
    = (   (   (vm_cons.l(ttot+1,all_regi)/pm_pop(ttot+1,all_regi))
            / (vm_cons.l(ttot-1,all_regi)/pm_pop(ttot-1,all_regi)) 
          )
          ** (1 / ( pm_ttot_val(ttot+1)- pm_ttot_val(ttot-1))) 
        - 1
      )
      + pm_prtp(all_regi);
  
  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload "REMIND2PyPSA.gdx",
    vm_prodSe, vm_prodFe, !! To scale up the load time series
    vm_costTeCapital, pm_data, p32_PyDisrate, !! To calculate annualised capital costs 
    pm_eta_conv, pm_dataeta, pm_PEPrice, p_priceCO2, fm_dataemiglob  !! To calculate marginal costs
    vm_cap, pm_dt, vm_deltaCap, vm_capEarlyReti !! To calculate pre-investment capacities
  ;

  !! Temporarily store and then set numeric round format and number of decimals
  sm_tmp  = logfile.nr;
  sm_tmp2 = logfile.nd;
  logfile.nr = 1;
  logfile.nd = 0;

  !! Copy REMIND2PyPSA for iteration i
  Put_utility logfile, "shell" /
    "cp REMIND2PyPSA.gdx REMIND2PyPSA_i" iteration.val:0:0 ".gdx";

  !! Run StartREMINDPyPSA.R (copied from scripts/iterative)
  !! This executes three steps, using the pik-piam/remindPypsa package
  !! 1) Process data from REMIND to PyPSA
  !! 2) Execute PyPSA
  !! 3) Process data from PyPSA to REMIND
  Put_utility logfile, "Exec" /
    "Rscript StartREMINDPyPSA.R %c32_pypsa_dir% " iteration.val:0:0;

  !! Copy PyPSA2REMIND from iteration i
  Put_utility logfile, "shell" / 
    "cp PyPSA2REMIND_i" iteration.val:0:0 ".gdx PyPSA2REMIND.gdx";

  !! Import PyPSA data for REMIND (PyPSA2REMIND.gdx)
  Execute_Loadpoint "PyPSA2REMIND.gdx", p32_Py2RM=PyPSA2REMIND;

  !! Reset round format and number of decimals
  logfile.nr = sm_tmp;
  logfile.nd = sm_tmp2;

  !! Capacity factor for dispatchable technologies
  !! TODO: Put in equation with prefactor
  loop (tePyMapDisp32(tePyImp32,tePy32),
    pm_cf(tPy32,regPy32,tePy32) =
      p32_Py2RM(tPy32,regPy32,tePyImp32,"capfac")
  );

  !! Capacity factor for non-dispatchable technologies with grades
  !! This uses pm_cf as a "correction factor" for the CFs in pm_dataren, weighted by vm_capDistr
  !! TODO: Put in equation with prefactor
  loop (tePyMapNondisp32(tePyImp32,tePy32),
    pm_cf(tPy32,regPy32,tePy32) =
        p32_Py2RM(tPy32,regPy32,tePyImp32,"capfac")
      * vm_cap.l(tPy32,regPy32,tePy32,"1")
      / sum(teRe2rlfDetail(tePy32,rlf), vm_capDistr.l(tPy32,regPy32,tePy32,rlf) * pm_dataren(regPy32,"nur",rlf,tePy32))
  );

);

*** EOF ./modules/32_power/PyPSA/postsolve.gms
