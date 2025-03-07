*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
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
pm_SEPrice(ttot,regi,entySe)$(abs (qm_budget.m(ttot,regi)) gt sm_eps AND sameas(entySe,"seel")) = 
       q32_balSe.m(ttot,regi,entySe) / qm_budget.m(ttot,regi);

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
***                  PyPSA-Eur pre-coupling
***------------------------------------------------------------

*** Before PyPSA execution make sure that budget equation is binding
*** Check that budget equation is binding if c32_checkPrice = 1
*** Optionally, also check that all PE prices are positive (currently disabled)
s32_checkPrice = 1;
if ((sm_PyPSA_eq eq 0 AND c32_checkPrice eq 1),
  loop ((tPy32, regPy32),
    if ((abs(qm_budget.m(tPy32,regPy32)) le sm_eps), !!  OR (pm_PEPrice(tPy32, regPy32, entyPePy32) lt 0
      s32_checkPrice = EPS;
      break;
    );
  );
*** If prefactors are used, check that v32_shSeElDisp is within reasonable bounds
$ifthen "%c32_pypsa_preFac%" == "on"
  loop ((tPy32,regPy32),
    if ((sum(tePy32, v32_shSeElDisp.l(tPy32,regPy32,tePy32)) gt 1.5) OR (sum(tePy32, v32_shSeElDisp.l(tPy32,regPy32,tePy32)) lt 0.5),
      s32_checkPrice = EPS;
      break;
    );
  );
$endif
);
*** Track s32_checkPrice over iterations
s32_checkPrice_iter(iteration) = s32_checkPrice;

*** Track PE price over iterations
p32_PEPrice_iter(iteration,ttot,regi,entyPe) = pm_PEPrice(ttot,regi,entyPe);

*** Calculate pre-investment capacities (for generation and storage/transmission technologies)
if (c32_pypsa_capacity eq 0,  !! Use pre-investment capacities
  p32_preInvCap(t,regi,te)$(tPy32(t) AND regPy32(regi) AND (tePy32(te) OR teStoreTransPy32(te)) AND NOT sameas(te, "hydro")) =
      max((vm_cap.l(t,regi,te,"1")
    - vm_deltaCap.l(t,regi,te,"1") * pm_ts(t) * ( 1 - vm_capEarlyReti.l(t,regi,te) )),
        1E-6);  !! Minimal capacity of 1 MW to avoid issues in PyPSA-Eur's RCL implementation
elseif (c32_pypsa_capacity eq 1),  !! Use full capacities
  p32_preInvCap(t,regi,te)$(tPy32(t) AND regPy32(regi) AND (tePy32(te) OR teStoreTransPy32(te)) AND NOT sameas(te, "hydro")) =
    max(vm_cap.l(t,regi,te,"1"), 1E-6);  !! Minimal capacity of 1 MW to avoid issues in PyPSA-Eur's RCL implementation
);

*** Track pre-investment capacities over iterations
p32_preInvCap_iter(iteration,t,regi,te) = p32_preInvCap(t,regi,te);

*** Special treatment for hydro: Don't use pre-investment capacity, but post-investment capacity instead
*** Also pass hydro generation to PyPSA, this is used to force PyPSA to REMIND's capacity factor
p32_hydroCap(t,regi)$(tPy32(t) AND regPy32(regi)) = vm_cap.l(t,regi,"hydro","1");
$ontext
*** Only calculate hydro generation if PyPSA is not executed yet because this determines the availability factor (not the capacity factor)
*** As the capacity factor (< availability factor) is returned from PyPSA this would otherwise trigger a downward spiral
if (sm_PyPSA_eq eq 0,
  p32_hydroGen(t,regi)$(tPy32(t) AND regPy32(regi)) = v32_usableSeTeDisp.l(t,regi,"seel","hydro");
);
$offtext
p32_hydroGen(t,regi)$(tPy32(t) AND regPy32(regi)) = v32_usableSeTeDisp.l(t,regi,"seel","hydro") * p32_hydroCorrectionFactor(t,regi);

***------------------------------------------------------------
***                  PyPSA-Eur coupling
***------------------------------------------------------------
if (( iteration.val ge c32_startIter_PyPSA ) AND  !! Only couple after c32_startIter_PyPSA
    ( mod(iteration.val - c32_startIter_PyPSA, c32_everyIter_PyPSA) eq 0 ) AND  !! Only couple every c32_everyIter_PyPSA iterations
    ( s32_checkPrice eq 1 ),  !! Only couple if budget equation is binding

  !! Track iterations in which PyPSA was executed
  s32_PyPSA_called(iteration) = 1;

  !! Electricity load
  p32_load(t,regi)$(tPy32(t) and regPy32(regi)) = v32_load.l(t,regi);

  !! Additional electrolytic hydrogen demand that is not used for storage
  !! vm_prodSe.l(t,regi,"seel","seh2","elh2") is the production of hydrogen from electrolysis (TWa w.r.t. hydrogen)
  !! vm_demSe.l(t,regi,"seh2","seel","h2turb") is the demand of hydrogen for electricity production (TWa w.r.t. hydrogen)
  !! The electrolyser efficiency is taken into account in PyPSA
  p32_ElecH2Demand(t,regi)$(tPy32(t) AND regPy32(regi)) =
      max(1E-8, vm_prodSe.l(t,regi,"seel","seh2","elh2") - vm_demSe.l(t,regi,"seh2","seel","h2turb")) + EPS;

*** REMIND to PyPSA-Eur: Calculate averages to reduce oscillations
*** (i) Pre-investment capacities
*** (ii) PE prices
*** The idea behind averaging follows three steps:
*** (1) Allow at least x iterations (until max(c32_startIter_PyPSA, x)) without averaging
*** (2) Allow another y iterations (until max(c32_startIter_PyPSA, x) + y) without averaging 
*** (3) Afterwards take the average of the previous y iterations, where y should be an even number
*** Currently set x to 3 and y to 2

  !! Implement step (1) and (2): Use non-averaged values always if c32_avg_rm2py = 0, or if iteration < c32_startIter_PyPSA + x + y - 1
  if (( c32_avg_rm2py eq 0 ) or ( iteration.val lt max(c32_startIter_PyPSA, 3) + 4 - 1 ),  !! c32_startIter_PYPSA + x + y - 1
    !! Non-averaged pre-investment capacities
    p32_preInvCapAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) OR teStoreTransPy32(te))) = p32_preInvCap(t,regi,te) + EPS;
    !! Non-averaged PE prices, limited to 0 and 200 EUR/MWh (for uranium 200 T$/Mt corresponds to 1752 $/kg)
    p32_PEPriceAvg(t,regi,entyPe)$(tPy32(t) and regPy32(regi) and entyPePy32(entyPe)) = 
        min(200 * sm_TWa_2_MWh/1E12, max(0, pm_PEPrice(t,regi,entyPe))) + EPS;
  !! Implement step (3): Use averaged values only if c32_avg_rm2py = 1 and (because of elseif) only if iteration >= c32_startIter_PyPSA + x + y - 1 
  elseif (c32_avg_rm2py eq 1),
      !! Average pre-investment capacities over past y iterations
      p32_preInvCapAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) OR teStoreTransPy32(te))) =
        sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_preInvCap_iter(iteration2,t,regi,te)) /
        sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2)) + EPS;
      !! Average non-negative PE prices over past y iterations, limited to 0 and 200 EUR/MWh (for uranium 200 T$/Mt corresponds to 1752 $/kg)
      p32_PEPriceAvg(t,regi,entyPe)$(tPy32(t) and regPy32(regi) and entyPePy32(entyPe)) =
        sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * min(200 * sm_TWa_2_MWh/1E12, max(0, p32_PEPrice_iter(iteration2,t,regi,entyPe)))) /
        sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2)) + EPS;
  );

  !! Capital interest rate aggregated for all regions in regPy32 (PyPSA-Eur has no regional costs yet)
  !! Also see calculation of p_r in core/postsolve.gms
  p32_discountRate(ttot)$(tPy32(ttot) and ttot.val le 2100) =
    1 / ( sum(regPy32(regi), pm_ies(regi)) / card(regPy32) ) * 
      ( ( ( sum(regPy32(regi), vm_cons.l(ttot+1,regi)) / sum(regPy32(regi), pm_pop(ttot+1,regi)) )
         /
          ( sum(regPy32(regi), vm_cons.l(ttot-1,regi)) / sum(regPy32(regi), pm_pop(ttot-1,regi)) )
        )
        ** ( 1 / ( pm_ttot_val(ttot+1) - pm_ttot_val(ttot-1) ) )
        - 1
      )
    + sum(regPy32(regi), pm_prtp(regi)) / card(regPy32)
    ;

  !! Limit p32_discountRate to 3-10%%
  p32_discountRate(ttot)$(tPy32(ttot) and ttot.val le 2100) = 
    min(0.1, max(0.02, p32_discountRate(ttot)));  !! Limit between 2% and 10%

  !! Set the interest rate to 0.03 after 2100
  p32_discountRate(ttot)$(ttot.val gt 2100) = 0.03;

  !! Specific capital costs plus adjustment costs
  if ((c32_adjCost eq 0),  !! No adjustment costs
    p32_capCostwAdjCost(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) or teStoreTransPy32(te))) = 
      vm_costTeCapital.l(t,regi,te) + EPS;
  elseif (c32_adjCost eq 1),  !! Average adjustment costs
    p32_capCostwAdjCost(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) or teStoreTransPy32(te))) = 
      max(0, vm_costTeCapital.l(t,regi,te) + o_avgAdjCostInv(t,regi,te)$( sum(te2rlf(te,rlf), vm_deltaCap.l(t,regi,te,rlf)) ge 1e-5 )) + EPS;
  elseif (c32_adjCost eq 2),  !! Marginal adjustment costs
    p32_capCostwAdjCost(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) or teStoreTransPy32(te))) = 
      max(0, vm_costTeCapital.l(t,regi,te) + o_margAdjCostInv(t,regi,te)$( sum(te2rlf(te,rlf), vm_deltaCap.l(t,regi,te,rlf)) ge 1e-5 )) + EPS;
  );

  !! Hack: Disincentivise oil by increasing their capital costs by factor 2
  !! Oil is sometimes used by PyPSA in 2025 only, which doesn't make sense as the investment wouldn't be profitable
  p32_capCostwAdjCost(t,regi,te)$(tPy32(t) and regPy32(regi) and sameas(te,"dot")) = 
      2 * p32_capCostwAdjCost(t,regi,te) + EPS;

  !! Parameters to calculate weighted averages across technologies and regions in PyPSA
  p32_weightGen(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePy32(te)) = v32_usableSeTeDisp.l(t,regi,"seel",te) + EPS;
  p32_weightStor(t,regi,te)$(tPy32(t) AND regPy32(regi) AND sameas(te,"elh2")) = vm_prodSe.l(t,regi,"seel","seh2","elh2") + EPS;
  p32_weightStor(t,regi,te)$(tPy32(t) AND regPy32(regi) AND sameas(te,"h2turb")) = vm_prodSe.l(t,regi,"seh2","seel","h2turb") + EPS;
  p32_weightPEprice(t,regi,entyPe)$(tPy32(t) AND regPy32(regi) AND entyPePy32(entyPe)) = vm_prodPe.l(t,regi,entyPe) + EPS;
  
  !! Also export zeros for CO2 price
  p_priceCO2(t,regi)$(tPy32(t) AND regPy32(regi)) = p_priceCO2(t,regi) + EPS;

  !! Export REMIND output data for PyPSA (REMIND2PyPSAEUR.gdx)
  !! Don't use fulldata.gdx so that we keep track of which variables are exported to PyPSA
  option epsToZero=on;
  Execute_Unload "REMIND2PyPSAEUR.gdx",
    !! -- REMIND to PyPSA-Eur --
    !! Coupled time steps, regions and technologies
    tPy32, regPy32, tePy32,
    !! Total electricity load
    p32_load,
    !! Additional electrolytic hydrogen demand (from other sectors)
    p32_ElecH2Demand,
    !! Capital cost components
    p32_capCostwAdjCost, pm_data, p32_discountRate,
    !! Marginal cost components
    pm_eta_conv, pm_dataeta, p32_PEPriceAvg, pe2se, p_priceCO2, fm_dataemiglob,
    !! Weights to calculate weighted averages
    p32_weightGen, p32_weightStor, p32_weightPEprice, 
    !! Pre-investment capacities
    p32_preInvCapAvg,
    !! Hydro capacities and generation
    p32_hydroCap, p32_hydroGen,
    !! -- PyPSA-Eur to REMIND -- 
    !! Generation shares in REMIND to downscale generation shares in PyPSA
    !! (this is required to parametrise the pre-factor equations) 
    v32_shSeElDisp
  ;
  option epsToZero=off;

  !! Temporarily store and then set numeric round format and number of decimals
  sm_tmp  = logfile.nr;
  sm_tmp2 = logfile.nd;
  logfile.nr = 1;
  logfile.nd = 0;

  !! Execute PyPSA-Eur
  !! This executes a shell script (copied from scripts/iterative) and starts the full coupling workflow in snakemake:
  !! (1) Copy REMIND2PyPSAEUR.gdx to PyPSA-Eur directory
  !! (2) Start PyPSA-Eur, including all data processing steps
  !! (3) Copy PyPSAEUR2REMIND.gdx to REMIND directory
  Put_utility logfile, "Exec" /
  "./RunPyPSA-Eur.sh %c32_pypsa_dir% " iteration.val:0:0;

  !! Reset round format and number of decimals
  logfile.nr = sm_tmp;
  logfile.nd = sm_tmp2;

  !! Import PyPSA data for REMIND (PyPSAEUR2REMIND.gdx)
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_CF=capacity_factor;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_shSeEl=generation_share;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_MV=market_value;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_LoadPrice=load_price;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_Markup=markup;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_Curtailment=curtailment;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_PeakResLoadRel=peak_residual_load_relative;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_StoreTrans_Cap=storage_and_transmission_capacities;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_StoreTrans_CF=storage_and_transmission_capacity_factors;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_H2TurbRel=h2turb_storage_relative;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_BatteryDischargeRel=battery_storage_relative;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_Trade=crossborder_flow;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_TradePriceImport=crossborder_price_import;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_TradePriceExport=crossborder_price_export;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_shSeElRegi=generation_region_share;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_Potential=potential;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_AF=availability_factor;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_ElecPriceElectrolysis=electricity_price_electrolysis;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_gridLossesRel=grid_loss_relative;

  !! Temporary workaround to avoid overinvestment in REMIND:
  !! Limit markup to between -50 and +150 EUR/MWh
  !!p32_PyPSA_Markup(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePy32(te)) = 
  !!  min(150, max(-50, p32_PyPSA_Markup(t,regi,te)));

  !! Track capacity factors in iterations
  p32_PyPSA_CF_iter(iteration,t,regi,te) = p32_PyPSA_CF(t,regi,te);
  !! Track market values in iterations
  p32_PyPSA_MV_iter(iteration,t,regi,te) = p32_PyPSA_MV(t,regi,te);
  !! Track load price in iterations
  p32_PyPSA_LoadPrice_iter(iteration,t,regi,carrierPy32) = p32_PyPSA_LoadPrice(t,regi,carrierPy32);
  !! Track markup in iterations
  p32_PyPSA_Markup_iter(iteration,t,regi,te) = p32_PyPSA_Markup(t,regi,te);
  !! Track electricity price paid by electrolysis in iterations
  p32_PyPSA_ElecPriceElectrolysis_iter(iteration,t,regi) = p32_PyPSA_ElecPriceElectrolysis(t,regi);

*** PyPSA-Eur to REMIND: Calculate averages to reduce oscillations
*** (1) Capacity factors
*** (2) Market values (--> TODO:REMOVE)
*** (3) Electricity prices (--> TODO:REMOVE)
*** (4) Markups
*** The idea behind averaging is the same as for REMIND to PyPSA-Eur. See above.
*** Currently set x to 3 and y to 4
  if ((c32_avg_py2rm eq 0) or (iteration.val lt max(c32_startIter_PyPSA, 3) + 4 - 1),  !! c32_startIter_PYPSA + x + y - 1
    !! Non-averaged capacity factors
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_CF(t,regi,te);
    !! Non-averaged market values
    p32_PyPSA_MVAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_MV(t,regi,te);
    !! Non-averaged electricity prices
    p32_PyPSA_LoadPriceAvg(t,regi,carrierPy32)$(tPy32(t) and regPy32(regi)) = p32_PyPSA_LoadPrice(t,regi,carrierPy32);
    !! Non averaged markups
    p32_PyPSA_MarkupAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_Markup(t,regi,te);
    !! Non averaged electricity price paid by electrolysis
    p32_PyPSA_ElecPriceElectrolysisAvg(t,regi)$(tPy32(t) and regPy32(regi)) = p32_PyPSA_ElecPriceElectrolysis(t,regi);
  !! Implement step (3)
  elseif (c32_avg_py2rm eq 1),
    !! Averaged capacity factors over iterations
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_CF_iter(iteration2,t,regi,te)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
    !! Averaged market values over iterations
    p32_PyPSA_MVAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_MV_iter(iteration2,t,regi,te)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
    !! Averaged electricity prices over iterations
    p32_PyPSA_LoadPriceAvg(t,regi,carrierPy32)$(tPy32(t) and regPy32(regi)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_LoadPrice_iter(iteration2,t,regi,carrierPy32)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
    !! Averaged markups over iterations
    p32_PyPSA_MarkupAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_Markup_iter(iteration2,t,regi,te)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
    !! Averaged electricity price paid by electrolysis over iterations
    p32_PyPSA_ElecPriceElectrolysisAvg(t,regi)$(tPy32(t) and regPy32(regi)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_ElecPriceElectrolysis_iter(iteration2,t,regi)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
  );
  
  !! TODO: REMOVE
  !! Save v32_usableSeDispNet for next iteration's electricity trade implementation
  !!p32_usableSeDispNet0(t,regi,"seel")$(tPy32(t) AND regPy32(regi)) = v32_usableSeDispNet.l(t,regi,"seel");

*** Activate PyPSA equations if PyPSA ran once
sm_PyPSA_eq = 1;
);

***------------------------------------------------------------
***                  PyPSA-Eur reporting
***------------------------------------------------------------

$ifthen "%c32_pypsa_peakcap%" == "on"
if ((sm_PyPSA_eq eq 1),
*** Calculate shadow price of peak residual load constraint
p32_PeakResLoadShadowPrice(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePyDisp32(te) AND ((qm_budget.m(t,regi) * p32_PyPSA_CFAvg(t,regi,te) ) ne 0))  =
      q32_PeakResCap.m(t,regi)
  / ( qm_budget.m(t,regi) * p32_PyPSA_CFAvg(t,regi,te) );
*** Report electricity balance equation components
*** Supply
p32_ElecBalance(t,regi,"1")$(tPy32(t) and regPy32(regi)) = sum(pe2se(enty,enty2,te)$(sameas(enty2,"seel")), vm_prodSe.l(t,regi,enty,enty2,te) );
p32_ElecBalance(t,regi,"2")$(tPy32(t) and regPy32(regi)) = sum(se2se(enty,enty2,te)$(sameas(enty2,"seel")), vm_prodSe.l(t,regi,enty,enty2,te) );
p32_ElecBalance(t,regi,"3")$(tPy32(t) and regPy32(regi)) = sum(pc2te(enty,entySe(enty3),te,enty2)$(sameas(enty2,"seel")), 
                              pm_prodCouple(regi,enty,enty3,te,enty2) * vm_prodSe.l(t,regi,enty,enty3,te) );
p32_ElecBalance(t,regi,"4")$(tPy32(t) and regPy32(regi)) = sum(pc2te(enty4,entyFe(enty5),te,enty2)$(sameas(enty2,"seel")), 
                              pm_prodCouple(regi,enty4,enty5,te,enty2) * vm_prodFe.l(t,regi,enty4,enty5,te) );
p32_ElecBalance(t,regi,"5")$(tPy32(t) and regPy32(regi)) = sum(pc2te(enty,enty3,te,enty2)$(sameas(enty2,"seel")),
                                sum(teCCS2rlf(te,rlf),
                                  pm_prodCouple(regi,enty,enty3,te,enty2) * vm_co2CCS.l(t,regi,enty,enty3,te,rlf) ) );
p32_ElecBalance(t,regi,"6")$(tPy32(t) and regPy32(regi)) = vm_Mport.l(t,regi,"seel");
*** Withdrawal
p32_ElecBalance(t,regi,"7")$(tPy32(t) and regPy32(regi)) = sum(se2fe(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(t,regi,enty2,enty3,te) );
p32_ElecBalance(t,regi,"8")$(tPy32(t) and regPy32(regi)) = sum(se2se(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(t,regi,enty2,enty3,te) );
p32_ElecBalance(t,regi,"9")$(tPy32(t) and regPy32(regi)) = sum(teVRE, v32_storloss.l(t,regi,teVRE) );
p32_ElecBalance(t,regi,"10")$(tPy32(t) and regPy32(regi)) = sum(pe2rlf(enty3,rlf2), (pm_fuExtrOwnCons(regi, "seel", enty3) * vm_fuExtr.l(t,regi,enty3,rlf2))$(pm_fuExtrOwnCons(regi, "seel", enty3) gt 0))$(t.val > 2005);
p32_ElecBalance(t,regi,"11")$(tPy32(t) and regPy32(regi)) = vm_Xport.l(t,regi,"seel");
p32_ElecBalance(t,regi,"12")$(tPy32(t) and regPy32(regi)) = v32_gridLosses.l(t,regi);
);
$endif


*** EOF ./modules/32_power/PyPSA/postsolve.gms
