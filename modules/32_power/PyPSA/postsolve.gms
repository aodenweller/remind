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

*** Track PE price in iterations
p32_PEPrice_iter(iteration,ttot,regi,entyPe) = pm_PEPrice(ttot,regi,entyPe);

*** Check that budget equation is binding and that all PE prices are positive for all PyPSA time steps and regions
s32_checkPrice = 1;
loop ((tPy32, regPy32, entyPePy32),
  if ((abs(qm_budget.m(tPy32,regPy32)) le sm_eps) OR (pm_PEPrice(tPy32, regPy32, entyPePy32) lt 0),
    s32_checkPrice = 0;
    break;
  );
);
s32_checkPrice_iter(iteration) = s32_checkPrice;

***------------------------------------------------------------
***                  Only execute every X-th iteration
***------------------------------------------------------------
if ( (s32_checkPrice eq 1) AND (iteration.val ge c32_startIter_PyPSA), !!  AND (mod(iteration.val - c32_startIter_PyPSA, 1) eq 0)
  
  !! TODO: Shift pre-investment capacites and preInvCap_iter before loop so that values are available for all iteraions (for averaging)
  !! Pre-investment capacities
  p32_preInvCap(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePy32(te)) =
    max(1e-8,  !! Require minimum value
        vm_cap.l(t,regi,te,"1")
      - vm_deltaCap.l(t,regi,te,"1") * pm_ts(t) * ( 1 - vm_capEarlyReti.l(t,regi,te) )
      - p32_iniCapPHS(regi,te)
       )
  ;
  !! Track pre-investment capacities in iterations
  p32_preInvCap_iter(iteration,t,regi,te) = p32_preInvCap(t,regi,te);

*** REMIND to PyPSA-Eur: Calculate averages to reduce oscillations
*** (i) Pre-investment capacities
*** (ii) PE prices
*** The idea behind averaging follows three steps:
*** (1) allow x iterations (until c32_startIter_PyPSA + x) without averaging so that variables can adjust/drift
*** (2) allow another y iterations (until c32_startIter + x + y) without averaging so that variables can start oscillating
*** (3a) afterwards (from c32_startIter + x + y) take the average of the previous y iterations, where y should be an even number
*** (3b) afterwards (from c32_startIter + x + y) take the average of all previous iterations larger than c32_startIter + x
*** 3b might lead to over-damping, while 3a could lead to under-damping for heavily-oscillating technologies
*** Currently we use 3a and set x to 3 and y to 4

  !! Implement step (1) and (2)
  if ((c32_avg_rm2py eq 0) or (iteration.val lt c32_startIter_PyPSA + 3 + 4 - 1),  !! c32_startIter_PYPSA + x + y - 1
    !! Non-averaged pre-investment capacities
    p32_preInvCapAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_preInvCap(t,regi,te);
    !! Non-averaged PE prices
    p32_PEPriceAvg(t,regi,entyPe)$(tPy32(t) and regPy32(regi)) = max(0, pm_PEPrice(t,regi,entyPe));  !! Prevent negative PE prices
  !! Implement step (3)
  elseif (c32_avg_rm2py eq 1),
    !!! Averaged pre-investment capacities over iterations
    p32_preInvCapAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
        sum(iteration2$(iteration2.val gt (iteration.val - 4)),
            s32_checkPrice_iter(iteration2) * p32_preInvCap_iter(iteration2,t,regi,te))
      / sum(iteration2$(iteration2.val gt (iteration.val - 4)),
            s32_checkPrice_iter(iteration2));  !! (3a)
      !!sum(iteration2$(iteration2.val ge (c32_startIter_PyPSA + 3)), p32_preInvCap_iter(iteration2,t,regi,te)) / (iteration.val - 3);  !! (3b)
    !! Averaged PE prices over iterations
    p32_PEPriceAvg(t,regi,entyPe)$(tPy32(t) and regPy32(regi) and entyPePy32(entyPe)) =
        sum(iteration2$(iteration2.val gt (iteration.val - 4)),
            s32_checkPrice_iter(iteration2) * p32_PEPrice_iter(iteration2,t,regi,entyPe))
      / sum(iteration2$(iteration2.val gt (iteration.val - 4)),
            s32_checkPrice_iter(iteration2)); !! (3a)
      !!sum(iteration2$(iteration2.val ge (c32_startIter_PyPSA + 3)), max(0, p32_PEPrice_iter(iteration2,t,regi,entyPe))) / (iteration.val - 3); !! (3b)
  );

  !! Capital interest rate aggregated for all regions in regPy32
  p32_discountRate(ttot)$(ttot.val gt 2005 and ttot.val le 2130) =
    ( (  ( sum(regPy32(regi), vm_cons.l(ttot+1,regi)) / sum(regPy32(regi), pm_pop(ttot+1,regi)) )
       / ( sum(regPy32(regi), vm_cons.l(ttot-1,regi)) / sum(regPy32(regi), pm_pop(ttot-1,regi)) )
      )
      ** ( 1 / ( pm_ttot_val(ttot+1)- pm_ttot_val(ttot-1) ) )
      - 1
    )
    + sum(regPy32(regi), pm_prtp(regi)) / card(regPy32)
  ;
  !! Set the interest rate to 0.05 after 2100
  p32_discountRate(ttot)$(ttot.val gt 2100) = 0.05;

  !! Specific capital costs and adjustment costs
  p32_capCostwAdjCost(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = 
    max(0, vm_costTeCapital.l(t,regi,te) + o_avgAdjCostInv(t,regi,te));

  !! Export REMIND output data for PyPSA (REMIND2PyPSA.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  Execute_Unload "REMIND2PyPSAEUR.gdx",
    !! REMIND to PyPSA
    tPy32, regPy32, tePy32, !! General info: Coupled time steps, regions and technologies
    v32_usableSeDisp, !! Load
    p32_capCostwAdjCost, pm_data, p_r, p32_discountRate, !! Capital cost components
    pm_eta_conv, pm_dataeta, p32_PEPriceAvg, pe2se, p_priceCO2, fm_dataemiglob,  !! Marginal cost components
    p32_preInvCapAvg, !! Pre-investment capacities
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

  !! Track capacity factors and market values in iterations
  p32_PyPSA_CF_iter(iteration,t,regi,te) = p32_PyPSA_CF(t,regi,te);
  p32_PyPSA_MV_iter(iteration,t,regi,te) = p32_PyPSA_MV(t,regi,te);

*** PyPSA-Eur to REMIND: Calculate averages to reduce oscillations
*** (i) Capacity factors
*** (ii) Market values
*** The idea behind averaging is the same as for REMIND to PyPSA-Eur. See above.
*** Currently set x to 3 and y to 4
  if ((c32_avg_py2rm eq 0) or (iteration.val lt c32_startIter_PyPSA + 3 + 4 - 1),  !! c32_startIter_PYPSA + x + y - 1
    !! Non-averaged capacity factors
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_CF(t,regi,te);
    !! Non-averaged market values
    p32_PyPSA_MVAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_MV(t,regi,te);
  !! Implement step (3)
  elseif (c32_avg_py2rm eq 1),
    !! Averaged capacity factors over iterations
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), p32_PyPSA_CF_iter(iteration2,t,regi,te)) / 4;  !! (3a)
      !!sum(iteration2$(iteration2.val ge (c32_startIter_PyPSA + 3)), p32_PyPSA_CF_iter(iteration2,t,regi,te)) / (iteration.val - 3);  !! (3b)
    !! Averaged market values over iterations
    p32_PyPSA_MVAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), p32_PyPSA_MV_iter(iteration2,t,regi,te)) / 4; !! (3a)
      !!sum(iteration2$(iteration2.val ge (c32_startIter_PyPSA + 3)), p32_PyPSA_MV_iter(iteration2,t,regi,te)) / (iteration.val - 3); !! (3b)
  );

*** Activate PyPSA equations from 
sm_PyPSA_eq = 1;

);


*** EOF ./modules/32_power/PyPSA/postsolve.gms
