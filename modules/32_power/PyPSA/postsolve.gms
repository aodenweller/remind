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
*** If anticipation factors are used, check that v32_shPe2seel is within reasonable bounds
$ifthen "%c32_pypsa_anticipation%" == "manual"
  loop ((tPy32,regPy32),
    if ((sum(tePy32, v32_shPe2seel.l(tPy32,regPy32,tePy32)) gt 1.5) OR (sum(tePy32, v32_shPe2seel.l(tPy32,regPy32,tePy32)) lt 0.5),
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
p32_hydroGen(t,regi)$(tPy32(t) AND regPy32(regi)) = v32_pe2seelTe.l(t,regi,"hydro") * p32_hydroCorrectionFactor(t,regi);

***------------------------------------------------------------
***                  PyPSA-Eur coupling
***------------------------------------------------------------
if (( iteration.val ge c32_startIter_PyPSA ) AND  !! Only start after c32_startIter_PyPSA
    ( mod(iteration.val - c32_startIter_PyPSA, c32_everyIter_PyPSA) eq 0 ) AND  !! Only start every c32_everyIter_PyPSA iterations
    ( s32_checkPrice eq 1 ),  !! Only start if budget equation is binding

  !! Track iterations in which PyPSA was executed, this is necessary to calculate averages
  s32_PyPSA_called(iteration) = 1;

  !! Electricity load
  !! TODO: Remove and just pass v32_load instead
  p32_load(t,regi)$(tPy32(t) and regPy32(regi)) = v32_load.l(t,regi);

  !! Additional electrolytic hydrogen demand that is not used for storage. This is the difference between:
  !! (1) vm_prodSe.l(t,regi,"seel","seh2","elh2") is the production of hydrogen from electrolysis (TWa hydrogen)
  !! (2) vm_demSe.l(t,regi,"seh2","seel","h2turb") is the demand of hydrogen for electricity production (TWa hydrogen)
  !! Note that electrolyser efficiency is taken into account in PyPSA
  p32_ElecH2Demand(t,regi)$(tPy32(t) AND regPy32(regi)) =
      max(1E-8, vm_prodSe.l(t,regi,"seel","seh2","elh2") - vm_demSe.l(t,regi,"seh2","seel","h2turb")) + EPS;

*** REMIND to PyPSA-Eur: Calculate averages to reduce oscillations
*** (i) Pre-investment capacities
*** (ii) Primary energy (PE) prices
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

  !! Limit p32_discountRate to 3-10%
  p32_discountRate(ttot)$(tPy32(ttot) and ttot.val le 2100) = 
    min(0.1, max(0.02, p32_discountRate(ttot)));  !! Limit between 2% and 10%

  !! Set the interest rate to 3% after 2100
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

  !! Hack: Disincentivise oil and nuclear by increasing capital costs by factor 2
  !! Oil and nuclear are sometimes used by PyPSA in 2025 only, which doesn't make sense as the investment wouldn't be profitable
  !! TODO: Find a way to properly include foresight of key metrics (capacity factors, markups) into capital cost
  p32_capCostwAdjCost(t,regi,te)$(tPy32(t) and regPy32(regi) and (sameas(te,"dot") or sameas(te,"tnrs") or sameas(te, "fnrs")) ) = 
      2 * p32_capCostwAdjCost(t,regi,te) + EPS;

  !! Parameters to calculate weighted averages across technologies and regions in PyPSA
  p32_weightGen(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePy32(te)) = v32_pe2seelTe.l(t,regi,te) + EPS;
  p32_weightStor(t,regi,te)$(tPy32(t) AND regPy32(regi) AND sameas(te,"elh2")) = vm_prodSe.l(t,regi,"seel","seh2","elh2") + EPS;
  p32_weightStor(t,regi,te)$(tPy32(t) AND regPy32(regi) AND sameas(te,"h2turb")) = vm_prodSe.l(t,regi,"seh2","seel","h2turb") + EPS;
  p32_weightPEprice(t,regi,entyPe)$(tPy32(t) AND regPy32(regi) AND entyPePy32(entyPe)) = vm_prodPe.l(t,regi,entyPe) + EPS;
  
  !! Also export zeros for CO2 price
  p_priceCO2(t,regi)$(tPy32(t) AND regPy32(regi)) = p_priceCO2(t,regi) + EPS;

  !! Export REMIND config for PyPSA (REMIND2PyPSAEUR_config.gdx)
  !! This contains switches, which are read in in PyPSA with import_REMIND_config.py
  !! See main.gms for the definition of the switches
  option epsToZero=on;
  Execute_Unload "REMIND2PyPSAEUR_config.gdx"
    c32_pypsa_cfg_nodes,  !! Number of nodes
    c32_pypsa_cfg_hourly_res,  !! Hourly resolution
    c32_pypsa_cfg_rcl_generators,  !! Enable RCL constraint for generators
    c32_pypsa_cfg_rcl_links,  !! Enable RCL constraint for links
    c32_pypsa_cfg_rcl_stores,  !! Enable RCL constraint for stores
    c32_pypsa_perturb  !! Automatically set if c32_pypsa_anticipation=="diffQuot"
  ;
  !! Export REMIND data for PyPSA (REMIND2PyPSAEUR.gdx)
  Execute_Unload "REMIND2PyPSAEUR.gdx",
    !! -- REMIND to PyPSA-Eur --
    !! Coupled time steps, regions and technologies
    tPy32, regPy32, tePy32,
    !! Electricity load
    p32_load,
    !! Additional electrolytic hydrogen demand (from outside power sector)
    p32_ElecH2Demand,
    !! Capital cost components
    p32_capCostwAdjCost, pm_data, p32_discountRate,
    !! Marginal cost components
    pm_eta_conv, pm_dataeta, p32_PEPriceAvg, pe2se, p_priceCO2, fm_dataemiglob,
    !! Weights to calculate weighted averages
    p32_weightGen, p32_weightStor, p32_weightPEprice,
    !! Pre-installed capacities
    p32_preInvCapAvg,
    !! Hydro capacities and generation (special treatment in PyPSA)
    p32_hydroCap, p32_hydroGen,
    !! -- PyPSA-Eur to REMIND -- 
    !! Generation shares in REMIND to downscale generation shares in PyPSA
    v32_shPe2seel
  ;
  option epsToZero=off;

  !! Temporarily store and then set numeric round format and number of decimals
  sm_tmp  = logfile.nr;
  sm_tmp2 = logfile.nd;
  logfile.nr = 1;
  logfile.nd = 0;

  !! Run PyPSA-Eur
  !! This executes a shell script (copied from scripts/iterative) and starts the full coupling workflow in snakemake
  !! (1) Copy REMIND2PyPSAEUR_config.gdx and REMIND2PyPSAEUR.gdx to PyPSA-Eur resources directory
  !! (2) Create PyPSA config yaml file using REMIND2PyPSAEUR_config.gdx (first snakemake command)
  !! (3) Run PyPSA, including all data pre- and postprocessing, using the the yaml file (second snakemake command)
  !! (3) Copy PyPSAEUR2REMIND.gdx to REMIND scenario output folder
  !! The PyPSA directory and the current iteration are passed as arguments to the shell script
  Put_utility logfile, "Exec" /
  "./RunPyPSA-Eur.sh %c32_pypsa_dir% " iteration.val:0:0;

  !! Reset round format and number of decimals
  logfile.nr = sm_tmp;
  logfile.nd = sm_tmp2;

  !! Import PyPSA data for REMIND (PyPSAEUR2REMIND.gdx)
  !! The PyPSAEUR2REMIND.gdx is created by export_to_REMIND in PyPSA-Eur
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_CF=capacity_factors;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_MarkupSupply=markups_supply;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_PeakResLoadRel=peak_residual_loads;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_MarkupDemand=markups_demand;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_shPe2seel=generation_shares;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_OptCap=optimal_capacities;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_Potential=potentials;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_H2TurbRel=hydrogen_storage_generation;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_BatteryDischargeRel=battery_storage_generation;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_GridLossesRel=grid_losses;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_AF=availability_factors;
$ifthen "%c32_pypsa_anticipation%" == "diffQuot"
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_DQ_CF=difference_quotient_capacity_factors;
  Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_DQ_MarkupSupply=difference_quotient_markups_supply;
$endif

  !! Track capacity factors in iterations
  p32_PyPSA_CF_iter(iteration,t,regi,te) = p32_PyPSA_CF(t,regi,te);
  !! Track supply-side markup in iterations
  p32_PyPSA_MarkupSupply_iter(iteration,t,regi,te) = p32_PyPSA_MarkupSupply(t,regi,te);
  !! Track demand-side markup in iterations
  p32_PyPSA_MarkupDemand_iter(iteration,t,regi,loadPy32) = p32_PyPSA_MarkupDemand(t,regi,loadPy32);

*** PyPSA-Eur to REMIND: Calculate averages to reduce oscillations
*** (1) Capacity factors
*** (2) Markups
*** The idea behind averaging is the same as for REMIND to PyPSA-Eur. See above.
*** Currently set x to 3 and y to 4
  if ((c32_avg_py2rm eq 0) or (iteration.val lt max(c32_startIter_PyPSA, 3) + 4 - 1),  !! c32_startIter_PYPSA + x + y - 1
    !! Non-averaged capacity factors
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_CF(t,regi,te);
    !! Non averaged supply-side markup
    p32_PyPSA_MarkupSupplyAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_MarkupSupply(t,regi,te);
    !! Non averaged demand-side markup
    p32_PyPSA_MarkupDemandAvg(t,regi,loadPy32)$(tPy32(t) and regPy32(regi)) = p32_PyPSA_MarkupDemand(t,regi,loadPy32);
  !! Implement step (3)
  elseif (c32_avg_py2rm eq 1),
    !! Averaged capacity factors over iterations
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_CF_iter(iteration2,t,regi,te)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
    !! Averaged markups over iterations
    p32_PyPSA_MarkupSupplyAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_MarkupSupply_iter(iteration2,t,regi,te)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
    !! Averaged markups over iterations
    p32_PyPSA_MarkupDemandAvg(t,regi,loadPy32)$(tPy32(t) and regPy32(regi)) =
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2) * p32_PyPSA_MarkupDemand_iter(iteration2,t,regi,loadPy32)) /
      sum(iteration2$(iteration2.val gt (iteration.val - 4)), s32_PyPSA_called(iteration2));
  );

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
p32_ElecBalance(t,regi,"7")$(tPy32(t) and regPy32(regi)) = v32_gridLosses.l(t,regi)$(tPy32(t) AND regPy32(regi) AND sm_PyPSA_eq eq 1);
*** Withdrawal
p32_ElecBalance(t,regi,"8")$(tPy32(t) and regPy32(regi)) = sum(se2fe(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(t,regi,enty2,enty3,te) );
p32_ElecBalance(t,regi,"9")$(tPy32(t) and regPy32(regi)) = sum(se2se(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(t,regi,enty2,enty3,te) );
p32_ElecBalance(t,regi,"10")$(tPy32(t) and regPy32(regi)) = sum(teVRE, v32_storloss.l(t,regi,teVRE) );
p32_ElecBalance(t,regi,"11")$(tPy32(t) and regPy32(regi)) = sum(pe2rlf(enty3,rlf2), (pm_fuExtrOwnCons(regi, "seel", enty3) * vm_fuExtr.l(t,regi,enty3,rlf2))$(pm_fuExtrOwnCons(regi, "seel", enty3) gt 0))$(t.val > 2005);
p32_ElecBalance(t,regi,"12")$(tPy32(t) and regPy32(regi)) = vm_Xport.l(t,regi,"seel");
p32_ElecBalance(t,regi,"13")$(tPy32(t) and regPy32(regi)) = v32_gridLosses.l(t,regi);
);
$endif


*** EOF ./modules/32_power/PyPSA/postsolve.gms
