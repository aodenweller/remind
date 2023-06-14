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
***                  PyPSA-Eur coupling
***------------------------------------------------------------

*** Execute PyPSA-Eur only every x-th iteration after iteration c32_startIter_PyPSA
if ( (iteration.val ge c32_startIter_PyPSA) and (mod(iteration.val - c32_startIter_PyPSA, 1) eq 0),

  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload "REMIND2PyPSA.gdx",
    !! REMIND to PyPSA
    vm_usableSe, !! To scale up the load time series
    vm_costTeCapital, pm_data, p_r, !! To calculate annualised capital costs 
    pm_eta_conv, pm_dataeta, pm_PEPrice, pe2se, p_priceCO2, fm_dataemiglob  !! To calculate marginal costs
    vm_cap, pm_dt, vm_deltaCap, vm_capEarlyReti !! To calculate pre-investment capacities
    !! PyPSA to REMIND
    v32_shSeElDisp  !! To downscale PyPSA generation shares to REMIND technologies
  ;

  !! Temporarily store and then set numeric round format and number of decimals
  sm_tmp  = logfile.nr;
  sm_tmp2 = logfile.nd;
  logfile.nr = 1;
  logfile.nd = 0;

$ontext
  !! Copy REMIND2PyPSA.gdx for iteration i
  Put_utility logfile, "shell" /
  !!  "cp REMIND2PyPSA.gdx REMIND2PyPSA_i" iteration.val:0:0 ".gdx";

  !! Start PyPSA-Eur
  !! This executes a shell script (copied from scripts/iterative)
  !! and starts the full coupling workflow:
  !! 1) Transfer data from REMIND to PyPSA-Eur (REMIND2PyPSA.gdx)
  !! 2) Start PyPSA-Eur
  !! 3) Transfer data from PyPSA-Eur to REMIND (PyPSA2REMIND.gdx)
  Put_utility logfile, "Exec" /
  "./RunPyPSA-Eur.sh %c32_pypsa_dir% " iteration.val:0:0;

  !! Copy PyPSA2REMIND from iteration i
  Put_utility logfile, "shell" / 
    "cp PyPSA2REMIND_i" iteration.val:0:0 ".gdx PyPSA2REMIND.gdx";
$offtext

  !! Import PyPSA data for REMIND (PyPSA2REMIND.gdx)
  Execute_Loadpoint "coupling-parameters.gdx", p32_PyPSA_CF=capacity_factor;
  Execute_Loadpoint "coupling-parameters.gdx", p32_PyPSA_shSeEl=generation_share;
  !!Execute_Loadpoint "coupling-parameters.gdx", p32_PyPSA_MV=market_value;

  !! Reset round format and number of decimals
  logfile.nr = sm_tmp;
  logfile.nd = sm_tmp2;

  !! Capacity factor for dispatchable technologies
  pm_cf(tPy32,regPy32,tePy32disp) = p32_PyPSA_CF(tPy32,regPy32,tePy32disp);

  !! Capacity factor for non-dispatchable technologies with grades
  !! This uses pm_cf as a "correction factor" for the CFs in pm_dataren, weighted by vm_capDistr
  pm_cf(tPy32,regPy32,tePy32nondisp) = p32_PyPSA_CF(tPy32,regPy32,tePy32nondisp)
                                     * vm_cap.l(tPy32,regPy32,tePy32nondisp,"1")
                                     / sum(teRe2rlfDetail(tePy32nondisp,rlf), vm_capDistr.l(tPy32,regPy32,tePy32nondisp,rlf) * pm_dataren(regPy32,"nur",rlf,tePy32nondisp));

  !!

);

*** EOF ./modules/32_power/PyPSA/postsolve.gms
