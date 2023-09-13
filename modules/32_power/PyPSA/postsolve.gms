*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
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
  
  !! Pre-investment capacities
  p32_preInvCap(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePy32(te)) =
    max(1e-8,  !! Require minimum value
      vm_cap.l(t,regi,te,"1")$(tPy32(t) AND regPy32(regi) AND tePy32(te))
    - vm_deltaCap.l(t,regi,te,"1")$(tPy32(t) AND regPy32(regi) AND tePy32(te))
    * (1 - vm_capEarlyReti.l(t,regi,te))$(tPy32(t) AND regPy32(regi) AND tePy32(te)));

  !! Capital interest rate aggregated for all regions in regPy32
  p32_discountRate(ttot)$(ttot.val gt 2005 and ttot.val le 2130) =
    ( (  ( sum(regPy32(regi), vm_cons.l(ttot+1,regi)) / sum(regPy32(regi), pm_pop(ttot+1,regi)) )
       / ( sum(regPy32(regi), vm_cons.l(ttot-1,regi)) / sum(regPy32(regi), pm_pop(ttot-1,regi)) )
      )
      ** (1 / ( pm_ttot_val(ttot+1)- pm_ttot_val(ttot-1)))
      - 1
    )
    + sum(regPy32(regi), pm_prtp(regi)) / card(regPy32)
  ;
  !! Set the interest rate to 0.05 after 2100
  p32_discountRate(ttot)$(ttot.val gt 2100) = 0.05;

  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload "REMIND2PyPSAEUR.gdx",
    !! REMIND to PyPSA
    tPy32, regPy32, tePy32, !! General info: Coupled time steps, regions and technologies
    v32_usableSeDisp, !! Load
    vm_costTeCapital, pm_data, p_r, p32_discountRate, !! Capital cost components
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

  !! Start PyPSA-Eur
  !! This executes a shell script (copied from scripts/iterative)
  !! and starts the full coupling workflow:
  !! 1) Copy REMIND2PyPSAEUR.gdx to PyPSA-Eur directory
  !! 2) Start PyPSA-Eur
  !! 3) Copy PyPSAEUR2REMIND.gdx to REMIND directory
  Put_utility logfile, "Exec" /
  "./RunPyPSA-Eur.sh %c32_pypsa_dir% " iteration.val:0:0;

  !! Reset round format and number of decimals
  logfile.nr = sm_tmp;
  logfile.nd = sm_tmp2;

  !! Import PyPSA data for REMIND (PyPSA2REMIND.gdx)
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_CF=capacity_factor;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_shSeEl=generation_share;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_MV=market_value;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_ElecPrice=electricity_price;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_Curtailment=curtailment;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_PeakResLoadRel=peak_residual_load_relative;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_PeakResLoadAbs=peak_residual_load_absolute;

);

*** EOF ./modules/32_power/PyPSA/postsolve.gms
