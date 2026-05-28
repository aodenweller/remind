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

*** Track PE price over iterations
p32_PEPrice_iter(iteration,ttot,regi,entyPe) = pm_PEPrice(ttot,regi,entyPe);

*** Calculate free capacities that are passed to PyPSA
if (iteration.val lt c32_iter_fullCap,  !! Use pre-investment capacities
    p32_cap(t,regi,te)$(tPy32(t) AND regPy32(regi) AND (tePy32(te) OR teStoreTransPy32(te)) AND NOT sameas(te, "hydro")) =
        max((vm_cap.l(t,regi,te,"1")
        - vm_deltaCap.l(t,regi,te,"1") * pm_ts(t) * ( 1 - vm_capEarlyReti.l(t,regi,te) )),
            1E-6);  !! Minimum capacity of 1 MW to avoid issues in PyPSA-Eur's RCL implementation
else  !! Use full capacities
    p32_cap(t,regi,te)$(tPy32(t) AND regPy32(regi) AND (tePy32(te) OR teStoreTransPy32(te)) AND NOT sameas(te, "hydro")) =
        max(vm_cap.l(t,regi,te,"1"), 1E-6);  !! Minimum capacity of 1 MW to avoid issues in PyPSA-Eur's RCL implementation
);

*** Track pre-investment capacities over iterations
p32_cap_iter(iteration,t,regi,te) = p32_cap(t,regi,te);

*** Special treatment for hydro: Pass full capacity and generation in separate variables
*** This is used to force PyPSA onto REMIND's capacity factor by adjusting the inflow time series in PyPSA
p32_hydroCapacity(t,regi)$(tPy32(t) AND regPy32(regi)) = vm_cap.l(t,regi,"hydro","1");
p32_hydroGeneration(t,regi)$(tPy32(t) AND regPy32(regi)) = v32_pe2seelTe.l(t,regi,"hydro");

***------------------------------------------------------------
***                  PyPSA averaging if converged
***------------------------------------------------------------

*** If PyPSA has converged in the previous iteration, pass average values of the previous x iterations to REMIND
if ((s32_pypsa_avg ne 1) AND  !! Only call once
    (
        ((s32_pypsa_conv eq 1) AND (iteration.val ge c32_minIter_PyPSA)) OR  !! If PyPSA has converged and at least c32_minIter_PyPSA iterations have passed
        (iteration.val ge c32_maxIter_PyPSA)  !! If at least c32_maxIter_PyPSA iterations have passed, irrespective of convergence 
    ),

    !! Store capacities of last iteration
    p32_lastCap(tPy32,regPy32,te)$(tePy32(te) OR teStoreTransPy32(te)) = vm_cap.l(tPy32,regPy32,te,"1");

    !! How many times was PyPSA called
    iter_counter = card(iterPyPSAcalled32)
    !! Count up over iteration2 while counting down over iter_counter
    loop(iteration2$(iterPyPSAcalled32(iteration2)),
        !! Get the last x iterations where PyPSA was called
        if (iter_counter <= c32_avgIter_PyPSA,
            iterPyPSAlastx32(iteration2) = yes;
        );
        iter_counter = iter_counter - 1;
    );

    !! Calculate averages over the last x iterations, where x is c32_avgIter_PyPSA
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_tech_iter(t,regi,te,iteration2,"CF"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_MarkupSupplyAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_tech_iter(t,regi,te,iteration2,"MarkupSupply"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_MarkupDemandAvg(t,regi,loadPy32)$(tPy32(t) and regPy32(regi) and loadPy32(loadPy32)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_load_iter(t,regi,loadPy32,iteration2,"MarkupDemand"))
    / (card(iterPyPSAlastx32) + sm_eps);
    !! Overwrite the previous values with the averaged values
    p32_PyPSA_OptCap(t,regi,te)$(tPy32(t) and regPy32(regi) and teStoreTransPy32(te)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_tech_iter(t,regi,te,iteration2,"OptCap"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_Potential(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_tech_iter(t,regi,te,iteration2,"Potential"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_PeakResLoadRel(t,regi)$(tPy32(t) and regPy32(regi)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_scalar_iter(t,regi,iteration2,"PeakResLoadRel"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_H2TurbRel(t,regi)$(tPy32(t) and regPy32(regi)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_scalar_iter(t,regi,iteration2,"H2TurbRel"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_BatteryDischargeRel(t,regi)$(tPy32(t) and regPy32(regi)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_scalar_iter(t,regi,iteration2,"BatteryDischargeRel"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_GridLossesRel(t,regi)$(tPy32(t) and regPy32(regi)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_scalar_iter(t,regi,iteration2,"GridLossesRel"))
    / (card(iterPyPSAlastx32) + sm_eps);
    p32_PyPSA_shPe2seel(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
        sum(iteration2$iterPyPSAlastx32(iteration2), p32_PyPSA_tech_iter(t,regi,te,iteration2,"shPe2seel"))
    / (card(iterPyPSAlastx32) + sm_eps);

    s32_pypsa_avg = 1;
);


***------------------------------------------------------------
***                  PyPSA-Eur coupling
***------------------------------------------------------------
if (( iteration.val ge c32_startIter_PyPSA ) AND  !! Only start after c32_startIter_PyPSA
    ( mod(iteration.val - c32_startIter_PyPSA, c32_everyIter_PyPSA) eq 0 ) AND  !! Only start every c32_everyIter_PyPSA iterations
    ( s32_checkPrice eq 1 ) AND  !! Only start if budget equation is binding
    ( iteration.val le c32_maxIter_PyPSA ) AND  !! Never call after this iteration
    (
        ( iteration.val le c32_minIter_PyPSA ) OR  !! Force calls until this iteration
        ( s32_pypsa_conv eq 0 )                    !! After that, only call if not converged
    ),

    !! Track iterations in which PyPSA was executed, this is necessary to calculate averages
    iterPyPSAcalled32(iteration) = yes;

    !! REMIND to PyPSA-Eur: Calculate averages to reduce oscillations
    !! (i) Capacities
    !! (ii) Primary energy (PE) prices
    !! The idea behind averaging follows three steps:
    !! (1) Allow at least x iterations (until max(c32_startIter_PyPSA, x)) without averaging
    !! (2) Allow another y iterations (until max(c32_startIter_PyPSA, x) + y) without averaging 
    !! (3) Afterwards take the average of the previous y iterations, where y should be an even number
    !! Currently set x to 3 and y to 2

    !! Implement step (1) and (2): Use non-averaged values always if c32_avg_rm2py = 0, or if iteration < c32_startIter_PyPSA + x + y - 1
    if (( c32_avg_rm2py eq 0 ) or ( iteration.val lt max(c32_startIter_PyPSA, 3) + 4 - 1 ),  !! c32_startIter_PYPSA + x + y - 1
        !! Non-averaged capacities
        p32_capAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) OR teStoreTransPy32(te))) = p32_cap(t,regi,te) + EPS;
        !! Non-averaged PE prices, limited to 0 and 200 EUR/MWh (for uranium 200 T$/Mt corresponds to 1752 $/kg)
        p32_PEPriceAvg(t,regi,entyPe)$(tPy32(t) and regPy32(regi) and entyPePy32(entyPe)) = 
            min(200 * sm_TWa_2_MWh/1E12, max(0, pm_PEPrice(t,regi,entyPe))) + EPS;
        !! Implement step (3): Use averaged values only if c32_avg_rm2py = 1 and (because of elseif) only if iteration >= c32_startIter_PyPSA + x + y - 1 
    elseif (c32_avg_rm2py eq 1),
        !! Average capacities over past y iterations
        p32_capAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and (tePy32(te) OR teStoreTransPy32(te))) =
            sum(iteration2$(iteration2.val gt (iteration.val - 4) and iterPyPSAcalled32(iteration2)), p32_cap_iter(iteration2,t,regi,te)) /
            sum(iteration2$(iteration2.val gt (iteration.val - 4) and iterPyPSAcalled32(iteration2)), 1) + EPS;
        !! Average non-negative PE prices over past y iterations, limited to 0 and 200 EUR/MWh (for uranium 200 T$/Mt corresponds to 1752 $/kg)
        p32_PEPriceAvg(t,regi,entyPe)$(tPy32(t) and regPy32(regi) and entyPePy32(entyPe)) =
            sum(iteration2$(iteration2.val gt (iteration.val - 4) and iterPyPSAcalled32(iteration2)), min(200 * sm_TWa_2_MWh/1E12, max(0, p32_PEPrice_iter(iteration2,t,regi,entyPe)))) /
            sum(iteration2$(iteration2.val gt (iteration.val - 4) and iterPyPSAcalled32(iteration2)), 1) + EPS;
    );

    !! Minimum biomass price of 30 USD/MWh
    p32_PEPriceAvg(tPy32,regPy32,"pebiolc") = 
        max(30 * sm_TWa_2_MWh/1E12, p32_PEPriceAvg(tPy32,regPy32,"pebiolc")) + EPS;

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

    !! Limit p32_discountRate to 2-10%
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

    !! Also export zeros for CO2 price
    p_priceCO2(t,regi)$(tPy32(t) AND regPy32(regi)) = p_priceCO2(t,regi) + EPS;

    !! Export REMIND data for PyPSA (REMIND2PyPSAEUR.gdx)
    !! This includes various demands, costs and parameters
    Execute_Unload "REMIND2PyPSAEUR.gdx",
        !! -- REMIND to PyPSA-Eur --
        !! Coupled time steps, regions and technologies
        tPy32, regPy32, tePy32,
        !! Sectoral electricity load
        v32_load_sector,
        !! Capital cost components
        p32_capCostwAdjCost, pm_data, p32_discountRate,
        !! Marginal cost components
        pm_eta_conv, pm_dataeta, p32_PEPriceAvg, pe2se, p_priceCO2, pm_emifac,
        !! Pre-installed capacities
        p32_capAvg,
        !! Hydro capacities and generation (forcing PyPSA onto REMIND's capacity factors)
        p32_hydroCapacity, p32_hydroGeneration
    ;
    option epsToZero=off;

    !! Temporarily store and then set numeric round format and number of decimals
    sm_tmp  = logfile.nr;
    sm_tmp2 = logfile.nd;
    logfile.nr = 1;
    logfile.nd = 0;

    !! Run PyPSA-Eur
    !! This executes a shell script (copied from scripts/iterative) and starts the full coupling workflow via pixi/snakemake
    !! The PyPSA directory, config changes file, config overrides string, and the current iteration are passed as arguments
    !! (1) Copy REMIND2PyPSAEUR.gdx to the PyPSA-Eur resources directory
    !! (2) Create config.remind_scenario.yaml with import_REMIND_config.py
    !! (3) Run PyPSA, including all data pre- and postprocessing, with the project Snakefile and the generated config file
    !! (4) Copy PyPSAEUR2REMIND.gdx to the REMIND scenario output folder
    Put_utility logfile, "Exec" /
    "./RunPyPSA-Eur.sh %c32_pypsa_dir% %c32_pypsa_cfg_file% %c32_pypsa_cfg_overrides% " iteration.val:0:0;

    !! Reset round format and number of decimals
    logfile.nr = sm_tmp;
    logfile.nd = sm_tmp2;

    !! Import PyPSA data for REMIND (PyPSAEUR2REMIND.gdx)
    !! The PyPSAEUR2REMIND.gdx is created by export_to_REMIND in PyPSA-Eur
    Execute_Loadpoint "PyPSAEUR2REMIND.gdx",
        !! Capacity factors of generation technologies
        p32_PyPSA_CF,
        !! Markups on the supply-side (market value minus avg price)
        p32_PyPSA_MarkupSupply,
        !! Market value of supply-side technologies
        p32_PyPSA_MarketValueSupply,
        !! Markups on the demand-side (sectoral price minus avg price)
        p32_PyPSA_MarkupDemand,
        !! Sectoral electricity prices
        p32_PyPSA_SectoralElectricityPrices,
        !! Average electricity price
        p32_PyPSA_AverageElectricityPrice,
        !! Relative residual load relative to load
        p32_PyPSA_PeakResLoadRel,
        !! Optimal capacities (for btstor and h2stor)
        p32_PyPSA_OptCap,
        !! Potentials
        p32_PyPSA_Potential,
        !! Hydrogen turbine generation relative to load
        p32_PyPSA_H2TurbRel,
        !! Battery discharge relative to load
        p32_PyPSA_BatteryDischargeRel,
        !! Grid losses relative to load
        p32_PyPSA_GridLossesRel,
        !! Generation share from PE carriers (for anticipation)
        p32_PyPSA_shPe2seel;
$ifthen "%c32_pypsa_anticipation%" == "diffQuot"
    Execute_Loadpoint "PyPSAEUR2REMIND.gdx", p32_PyPSA_DQ_CF, p32_PyPSA_DQ_MarkupSupply;
$endif

    !! Limit supply markups to 200 EUR/MWh
    p32_PyPSA_MarkupSupply(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) =
        min(200, p32_PyPSA_MarkupSupply(t,regi,te));

    !! Minimum of 1E-5 for p32_PyPSA_BatteryDischargeRel and p32_PyPSA_H2TurbRel
    !! to avoid issues with vm_cap.lo = 1E-7 by default (1E-5 = 0.001%, so negligible)
    p32_PyPSA_BatteryDischargeRel(t,regi)$(tPy32(t) and regPy32(regi)) =
        max(1E-5, p32_PyPSA_BatteryDischargeRel(t,regi));
    p32_PyPSA_H2TurbRel(t,regi)$(tPy32(t) and regPy32(regi)) =
        max(1E-5, p32_PyPSA_H2TurbRel(t,regi));

    !! Non-averaged values
    p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_CF(t,regi,te);
    p32_PyPSA_MarkupSupplyAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_MarkupSupply(t,regi,te);
    p32_PyPSA_MarkupDemandAvg(t,regi,loadPy32)$(tPy32(t) and regPy32(regi)) = p32_PyPSA_MarkupDemand(t,regi,loadPy32);

    !! Track all imports over iterations
    !! TODO: Change export in PyPSA-Eur to just export only three parameters (one for each group)?
    !! Parameters with technology dimension
    p32_PyPSA_tech_iter(tPy32,regPy32,te,iteration,"CF")$(tePy32(te) or teStoreTransPy32(te)) = p32_PyPSA_CF(tPy32,regPy32,te);
    p32_PyPSA_tech_iter(tPy32,regPy32,tePy32,iteration,"MarkupSupply") = p32_PyPSA_MarkupSupply(tPy32,regPy32,tePy32);
    p32_PyPSA_tech_iter(tPy32,regPy32,tePy32,iteration,"MarketValueSupply") = p32_PyPSA_MarketValueSupply(tPy32,regPy32,tePy32);
    p32_PyPSA_tech_iter(tPy32,regPy32,teStorePy32,iteration,"OptCap") = p32_PyPSA_OptCap(tPy32,regPy32,teStorePy32);
    p32_PyPSA_tech_iter(tPy32,regPy32,tePy32,iteration,"Potential") = p32_PyPSA_Potential(tPy32,regPy32,tePy32);
    p32_PyPSA_tech_iter(tPy32,regPy32,tePy32,iteration,"shPe2seel") = p32_PyPSA_shPe2seel(tPy32,regPy32,tePy32);
    !! Parameters with load dimension
    p32_PyPSA_load_iter(tPy32,regPy32,loadPy32,iteration,"MarkupDemand") = p32_PyPSA_MarkupDemand(tPy32,regPy32,loadPy32);
    p32_PyPSA_load_iter(tPy32,regPy32,loadPy32,iteration,"SectoralElectricityPrices") = p32_PyPSA_SectoralElectricityPrices(tPy32,regPy32,loadPy32);
    !! Parameters with no additional dimension (apart from time and region)
    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration,"PeakResLoadRel") = p32_PyPSA_PeakResLoadRel(tPy32,regPy32);
    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration,"BatteryDischargeRel") = p32_PyPSA_BatteryDischargeRel(tPy32,regPy32);
    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration,"H2TurbRel") = p32_PyPSA_H2TurbRel(tPy32,regPy32);
    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration,"GridLossesRel") = p32_PyPSA_GridLossesRel(tPy32,regPy32);
    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration,"AverageElectricityPrice") = p32_PyPSA_AverageElectricityPrice(tPy32,regPy32);

***------------------------------------------------------------
***                  PyPSA-Eur convergence
***------------------------------------------------------------

    !! Find last two iterations where PyPSA was called
    loop(iterPyPSAcalled32,
        iter_prev = iter_last;
        iter_last = iterPyPSAcalled32.val;
    );

    !! Calculate the convergence criterion for the imported parameters
    if (iter_prev gt 0,
        !! Parameters with technology dimension  
        loop(paramsPyTech32,
            !! Calculate convergence criterion for imported parameters with technology dimension
            p32_delta_tech(regPy32,te,paramsPyTech32,iteration)$(tePy32(te) OR teStoreTransPy32(te)) =
                sum((tPy32,iteration2),
                    p32_PyPSA_tech_iter(tPy32,regPy32,te,iteration2,paramsPyTech32)$(ord(iteration2) = iter_last)
                  - p32_PyPSA_tech_iter(tPy32,regPy32,te,iteration2,paramsPyTech32)$(ord(iteration2) = iter_prev)
                )
            /
                (sum((tPy32,iteration2),
                    p32_PyPSA_tech_iter(tPy32,regPy32,te,iteration2,paramsPyTech32)$(ord(iteration2) = iter_prev)
                ) + sm_eps);
        );
        !! Parameters with load dimension
        loop(paramsPyLoad32,
            !! Calculate convergence criterion for imported parameters with load dimension
            p32_delta_load(regPy32,loadPy32,paramsPyLoad32,iteration) =
                sum((tPy32,iteration2),
                    p32_PyPSA_load_iter(tPy32,regPy32,loadPy32,iteration2,paramsPyLoad32)$(ord(iteration2) = iter_last)
                  - p32_PyPSA_load_iter(tPy32,regPy32,loadPy32,iteration2,paramsPyLoad32)$(ord(iteration2) = iter_prev)
                )
            /
                (sum((tPy32,iteration2),
                    p32_PyPSA_load_iter(tPy32,regPy32,loadPy32,iteration2,paramsPyLoad32)$(ord(iteration2) = iter_prev)
                ) + sm_eps);
        );
        !! Parameters with no additional dimension (apart from time and region)
        loop(paramsPyScalar32,
            !! Calculate convergence criterion for imported parameters with no additional dimension
            p32_delta_scalar(regPy32,paramsPyScalar32,iteration) =
                sum((tPy32,iteration2),
                    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration2,paramsPyScalar32)$(ord(iteration2) = iter_last)
                  - p32_PyPSA_scalar_iter(tPy32,regPy32,iteration2,paramsPyScalar32)$(ord(iteration2) = iter_prev)
                )
                /
                (sum((tPy32,iteration2),
                    p32_PyPSA_scalar_iter(tPy32,regPy32,iteration2,paramsPyScalar32)$(ord(iteration2) = iter_prev)
                ) + sm_eps);
        );
        
        !! Calculate weighted average of the convergence criterion for capacity factors and supply-side markups
        !! TODO: Also include CF for storage technologies into average
        p32_delta_weighted(regPy32,paramsPyTech32,iteration)$(sameas(paramsPyTech32,"CF") or sameas(paramsPyTech32,"MarketValueSupply")) =
            sum((tePy32,tPy32),
                v32_pe2seelTe.l(tPy32,regPy32,tePy32)
                * abs(p32_delta_tech(regPy32,tePy32,paramsPyTech32,iteration))
            )
        /
            (sum((tePy32,tPy32),
                v32_pe2seelTe.l(tPy32,regPy32,tePy32)
            ) + sm_eps);

        !! Calculate non-weighted average for optimal capacity of battery and hydrogen storage
        p32_delta_weighted(regPy32,paramsPyTech32,iteration)$(sameas(paramsPyTech32,"OptCap")) =
            sum(teStorePy32, abs(p32_delta_tech(regPy32,teStorePy32,paramsPyTech32,iteration))) / card(teStorePy32);

        !! Calculate weighted average of the convergence criterion across all loads and time steps
        p32_delta_weighted(regPy32,paramsPyLoad32,iteration)$(sameas(paramsPyLoad32,"SectoralElectricityPrices")) =
            sum((loadPy32, tPy32),
                v32_share_sector.l(tPy32,regPy32,loadPy32)
                * abs(p32_delta_load(regPy32,loadPy32,paramsPyLoad32,iteration))
            )
        /
            (sum((loadPy32, tPy32),
                v32_share_sector.l(tPy32,regPy32,loadPy32)
            ) + sm_eps);

        !! Calculate weighted average of the convergence criterion across all time steps
        p32_delta_weighted(regPy32,paramsPyScalar32,iteration) =
            abs(p32_delta_scalar(regPy32,paramsPyScalar32,iteration));

       !! Check which iterations pass the convergence threshold in this iteration
        p32_below_threshold(regPy32, paramsPyCheck32, iteration)$(iterPyPSAcalled32(iteration)) = 
            (p32_delta_weighted(regPy32, paramsPyCheck32, iteration) <= p32_conv_threshold(regPy32, paramsPyCheck32));

        !! Check for which parameters the convergence threshold is not passed in the last 4 iterations
        p32_converged(regPy32, paramsPyCheck32, iteration)$(iterPyPSAcalled32(iteration)) =
            sum(iteration2$(iterPyPSAcalled32(iteration2) and ord(iteration2) > ord(iteration) - 4 and ord(iteration2) <= ord(iteration)),
                not p32_below_threshold(regPy32, paramsPyCheck32, iteration2)
            ) = 0;

        !! If any parameter does not pass the convergence threshold, set s32_pypsa_conv to 0
        s32_pypsa_conv = 1;
        loop((regPy32,paramsPyCheck32),
            if (not p32_converged(regPy32, paramsPyCheck32, iteration),
                s32_pypsa_conv = 0;
                break;
            );
        );
    );

    !! Activate PyPSA equations if PyPSA ran once
    sm_PyPSA_eq = 1;
);

***------------------------------------------------------------
***                  PyPSA-Eur reporting
***------------------------------------------------------------

$ifthen "%c32_pypsa_peakcap%" == "on"
if ((sm_PyPSA_eq eq 1),
    !! Calculate shadow price of peak residual load constraint
    p32_PeakResLoadShadowPrice(t,regi,te)$(tPy32(t) AND regPy32(regi) AND tePyDisp32(te) AND ((qm_budget.m(t,regi) * p32_PyPSA_CFAvg(t,regi,te) ) ne 0))  =
        q32_PeakResCap.m(t,regi)
    / ( qm_budget.m(t,regi) * p32_PyPSA_CFAvg(t,regi,te) );
    !! Report electricity balance equation components
    !! Supply
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
    !! Withdrawal
    p32_ElecBalance(t,regi,"7")$(tPy32(t) and regPy32(regi)) = sum(se2fe(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(t,regi,enty2,enty3,te) );
    p32_ElecBalance(t,regi,"8")$(tPy32(t) and regPy32(regi)) = sum(se2se(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(t,regi,enty2,enty3,te) );
    p32_ElecBalance(t,regi,"9")$(tPy32(t) and regPy32(regi)) = sum(teVRE, v32_storloss.l(t,regi,teVRE) );
    p32_ElecBalance(t,regi,"10")$(tPy32(t) and regPy32(regi)) = sum(pe2rlf(enty3,rlf2), (pm_fuExtrOwnCons(regi, "seel", enty3) * vm_fuExtr.l(t,regi,enty3,rlf2))$(pm_fuExtrOwnCons(regi, "seel", enty3) gt 0))$(t.val > 2005);
    p32_ElecBalance(t,regi,"11")$(tPy32(t) and regPy32(regi)) = vm_Xport.l(t,regi,"seel");
    p32_ElecBalance(t,regi,"12")$(tPy32(t) and regPy32(regi)) = v32_gridLosses.l(t,regi);
);
$endif

p32_load(ttot,regPy32) = 
    !! Demand for electricity from final energy sectors
    sum(se2fe(enty2,enty3,te)$(sameas(enty2,"seel")), vm_demSe.l(ttot,regPy32,enty2,enty3,te) )
    !! Add additional electricity load from electrolytic hydrogen production
    + v32_load_sector.l(ttot,regPy32,"electrolysis")
    !! Add electricity demand for fuel extraction
    + sum(pe2rlf(enty3,rlf2), (pm_fuExtrOwnCons(regPy32, "seel", enty3) * vm_fuExtr.l(ttot,regPy32,enty3,rlf2))$(pm_fuExtrOwnCons(regPy32, "seel", enty3) gt 0))$(ttot.val > 2005) !! do not use in 2005 because this demand is not contained in 05_initialCap
    !! Subtract electricity supply due to co-production of secondary energy
    !! This can also be negative, in which case it is added to the load
    - sum(pc2te(enty,entySe(enty3),te,enty2)$(sameas(enty2,"seel")), 
            pm_prodCouple(regPy32,enty,enty3,te,enty2) * vm_prodSe.l(ttot,regPy32,enty,enty3,te) )
    !! Subtract electricity supply due to co-production of final energy
    !! This can also be negative, in which case it is added to the load
    - sum(pc2te(enty4,entyFe(enty5),te,enty2)$(sameas(enty2,"seel")), 
            pm_prodCouple(regPy32,enty4,enty5,te,enty2) * vm_prodFe.l(ttot,regPy32,enty4,enty5,te) )
    !! Subtract electricity supply due to co-production of CCS (?)
    !! This can also be negative, in which case it is added to the load
    - sum(pc2te(enty,enty3,te,enty2)$(sameas(enty2,"seel")),
            sum(teCCS2rlf(te,rlf),
                pm_prodCouple(regPy32,enty,enty3,te,enty2) * vm_co2CCS.l(ttot,regPy32,enty,enty3,te,rlf) ) )
;

p32_load_sector(ttot,regPy32,"EV_pass") = 
    vm_demFeForEs.l(ttot,regPy32,"feelt","eselt_pass_sm","te_eselt_pass_sm")
  / pm_eta_conv(ttot,regPy32,"tdelt");
p32_load_sector(ttot,regPy32,"EV_freight") = 
    vm_demFeForEs.l(ttot,regPy32,"feelt","eselt_frgt_sm","te_eselt_frgt_sm")
  / pm_eta_conv(ttot,regPy32,"tdelt");
p32_load_sector(ttot,regPy32,"heatpump") =
    vm_cesIO.l(ttot,regPy32,"feelhpb")
  / pm_eta_conv(ttot,regPy32,"tdels");
p32_load_sector(ttot,regPy32,"resistive") =
    vm_cesIO.l(ttot,regPy32,"feelrhb")
  / pm_eta_conv(ttot,regPy32,"tdels");
p32_load_sector(ttot,regPy32,"electrolysis") =
    !! The bracket contains additional hydrogen load (TWa_H2),
    !! i.e. hydrogen production from electrolysis minus
    !! hydrogen demand for re-electrification in hydrogen turbines
    ( vm_prodSe.l(ttot,regPy32,"seel","seh2","elh2")
    - vm_demSe.l(ttot,regPy32,"seh2","seel","h2turb") )
    !! Divide by efficiency to get add. electricity load (TWa_elec)
    / pm_eta_conv(ttot,regPy32,"elh2");

p32_load_sector(ttot,regPy32,"AC") = p32_load(ttot,regPy32) - 
    p32_load_sector(ttot,regPy32,"EV_pass") - 
    p32_load_sector(ttot,regPy32,"EV_freight") - 
    p32_load_sector(ttot,regPy32,"heatpump") - 
    p32_load_sector(ttot,regPy32,"resistive") - 
    p32_load_sector(ttot,regPy32,"electrolysis");

*** EOF ./modules/32_power/PyPSA/postsolve.gms
