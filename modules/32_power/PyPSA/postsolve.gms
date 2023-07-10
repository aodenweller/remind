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

  p32_preInvCap(t,regi,te)$(tePy32(te)) = vm_cap.l(t,regi,te,"1")$(tePy32(te)) * (1 - vm_capEarlyReti.l(t,regi,te))$(tePy32(te))

  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload "REMIND2PyPSAEUR.gdx",
    !! REMIND to PyPSA
    tPy32, regPy32, tePy32, !! General info: Coupled time steps, regions and technologies
    v32_usableSeDisp, !! Load
    vm_costTeCapital, pm_data, p_r, !! Capital cost components
    pm_eta_conv, pm_dataeta, pm_PEPrice, pe2se, p_priceCO2, fm_dataemiglob  !! Marginal cost components
    p32_preInvCap, !! Pre-investment capacities
    v32_usableSeTeDisp, !! For weighted averages
    !! PyPSA to REMIND
    v32_shSeElDisp  !! To downscale PyPSA generation shares to REMIND technologies
  ;
  !! Temporarily store and then set numeric round format and number of decimals
  sm_tmp  = logfile.nr;
  sm_tmp2 = logfile.nd;
  logfile.nr = 1;
  logfile.nd = 0;

  !! Copy REMIND2PyPSA.gdx for iteration i
  Put_utility logfile, "shell" /
    "cp REMIND2PyPSAEUR.gdx REMIND2PyPSAEUR_i" iteration.val:0:0 ".gdx";

  !! Start PyPSA-Eur
  !! This executes a shell script (copied from scripts/iterative)
  !! and starts the full coupling workflow:
  !! 1) Copy REMIND2PyPSAEUR.gdx to PyPSA-Eur directory
  !! 2) Start PyPSA-Eur
  !! 3) Copy PyPSAEUR2REMIND.gdx to REMIND directory
  Put_utility logfile, "Exec" /
  "./RunPyPSA-Eur.sh %c32_pypsa_dir% " iteration.val:0:0;

  !! Copy PyPSA2REMIND from iteration i
  Put_utility logfile, "shell" / 
    "cp PyPSAEUR2REMIND.gdx PyPSAEUR2REMIND_" iteration.val:0:0.gdx;

  !! Import PyPSA data for REMIND (PyPSA2REMIND.gdx)
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_CF=capacity_factor;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_shSeEl=generation_share;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_MV=market_value;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_ElecPrice=electricity_price;

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
