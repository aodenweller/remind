*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/preloop.gms

***------------------------------------------------------------
***                  Preloop copied from IntC
***------------------------------------------------------------

*** read marginal of seel balance equation
Execute_Loadpoint 'input' q32_balSe.m = q32_balSe.m;

***------------------------------------------------------------
***                  PyPSA preloop
***------------------------------------------------------------

* Initialise variables
sm_PyPSA_eq = 0;
s32_pypsa_conv = 0;
s32_anticipationFactorFadeOut = 1;
p32_PyPSA_CF(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_CFAvg(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_MarkupSupplyAvg(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_MarkupDemandAvg(tPy32,regPy32,loadPy32) = 0;
p32_PyPSA_PeakResLoadRel(tPy32,regPy32) = 0;
p32_PyPSA_shPe2seel(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_Potential(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_H2TurbRel(tPy32,regPy32) = 0;
p32_PyPSA_BatteryDischargeRel(tPy32,regPy32) = 0;
p32_PyPSA_GridLossesRel(tPy32,regPy32) = 0;
p32_PyPSA_OptCap(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_DQ_CF(tPy32,regPy32,tePy32,tePy32) = 0;
p32_PyPSA_DQ_MarkupSupply(tPy32,regPy32,tePy32,tePy32) = 0;
p32_PyPSA_Trade(tPy32,regPy32,regPy32) = 0;
p32_PyPSA_TradePriceImport(tPy32,regPy32,regPy32) = 0;
p32_PyPSA_TradePriceExport(tPy32,regPy32,regPy32) = 0;
p32_PyPSA_shPe2seelRegi(tPy32,regPy32) = 0;
* Starting values for some variables
*v32_pe2seel.l(tPy32,regPy32) = 0;
*v32_pe2seelTe.l(tPy32,regPy32,tePy32) = 0;
*v32_shPe2seel.l(tPy32,regPy32,tePy32) = 0;
vm_Mport.l(tPy32,regPy32,"seel") = 0;
vm_Xport.l(tPy32,regPy32,"seel") = 0;
$ifthen "%c32_pypsa_peakcap%" == "on"
q32_PeakResCap.m(tPy32,regPy32) = 0;
$endif
$ifthen "%c32_pypsa_anticipation%" == "diffQuot"
c32_pypsa_cfg_perturb = 1;
$else
c32_pypsa_cfg_perturb = 0;
$endif

*** If c32_pypsa_startgdx is set, load the PyPSA data
*** This is used to start the PyPSA coupling with a previous run
$ifthen "%c32_pypsa_startgdx%" != "off"
Execute_Loadpoint "%c32_pypsa_startgdx%",
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
    p32_PyPSA_Potential
    !! Hydrogen turbine generation relative to load
    p32_PyPSA_H2TurbRel,
    !! Battery discharge relative to load
    p32_PyPSA_BatteryDischargeRel,
    !! Grid losses relative to load
    p32_PyPSA_GridLossesRel,
    !! Generation share from PE carriers (for anticipation)
    p32_PyPSA_shPe2seel;
*** Set required values
p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_CF(t,regi,te);
p32_PyPSA_MarkupSupplyAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_MarkupSupply(t,regi,te);
p32_PyPSA_MarkupDemandAvg(t,regi,loadPy32)$(tPy32(t) and regPy32(regi)) = p32_PyPSA_MarkupDemand(t,regi,loadPy32);
*** Activate all equations for the PyPSA coupling
sm_PyPSA_eq = 1;
$endif

*** EOF ./modules/32_power/PyPSA/preloop.gms
