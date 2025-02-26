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
s32_preFacFadeOut = 1;
p32_PyPSA_CFAvg(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_MVAvg(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_LoadPriceAvg(tPy32,regPy32,carrierPy32) = 0;
p32_PyPSA_MarkupAvg(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_PeakResLoadRel(tPy32,regPy32) = 0;
p32_PyPSA_Trade(tPy32,regPy32,regPy32) = 0;
p32_PyPSA_TradePriceImport(tPy32,regPy32,regPy32) = 0;
p32_PyPSA_TradePriceExport(tPy32,regPy32,regPy32) = 0;
p32_PyPSA_shSeEl(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_shSeElRegi(tPy32,regPy32) = 0;
p32_PyPSA_ValueFactor(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_Curtailment(tPy32,regPy32,tePyVRE32) = 0;
p32_PyPSA_Potential(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_ElecPriceElectrolysisAvg(tPy32,regPy32) = 0;
p32_gridLossesRel(tPy32,regPy32) = 0;
s32_PyPSA_called(iteration) = 0;
v32_usableSeDisp.l(tPy32,regPy32,"seel") = 0;
v32_shSeElDisp.l(tPy32,regPy32,tePy32) = 0;
vm_Mport.l(tPy32,regPy32,"seel") = 0;
vm_Xport.l(tPy32,regPy32,"seel") = 0;
p32_hydroCorrectionFactor(tPy32,regPy32) = 1;
p32_PyPSA_AF(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_CF(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_StoreTrans_Cap(tPy32,regPy32,storeTransPy32) = 0;
p32_PyPSA_StoreTrans_CF(tPy32,regPy32,storeTransPy32) = 0;
p32_PyPSA_H2TurbRel(tPy32,regPy32) = 0;
v32_usableSeTeDisp.l(tPy32,regPy32,"seel",tePy32) = 0;
$ifthen "%c32_pypsa_peakcap%" == "on"
q32_PeakResCap.m(tPy32,regPy32) = 0;
$endif

*** If c32_pypsa_pathgdx is set to a directory, import PyPSA variables
$ifthen not "%c32_pypsa_pathgdx%" == "off"
  display "Importing PyPSA variables from %c32_pypsa_pathgdx% in preloop.gms";
  !! Import data
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_CF=capacity_factor;
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_shSeEl=generation_share;
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_MV=market_value;
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_Markup=markup;
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_LoadPrice=load_price;
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_Curtailment=curtailment;
  Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_PeakResLoadRel=peak_residual_load_relative;
  !!Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_Trade=crossborder_flow;
  !!Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_TradePriceImport=crossborder_price;
  !!Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_TradePriceExport=crossborder_price;
  !!Execute_Loadpoint "%c32_pypsa_pathgdx%", p32_PyPSA_shSeElRegi=generation_region_share;
  !! Non-averaged capacity factors
  p32_PyPSA_CFAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_CF(t,regi,te);
  !! Non-averaged market values
  p32_PyPSA_MVAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_MV(t,regi,te);
  !! Non-averaged electricity prices
  p32_PyPSA_LoadPriceAvg(t,regi,carrierPy32)$(tPy32(t) and regPy32(regi)) = p32_PyPSA_LoadPrice(t,regi,carrierPy32);
  !! Non-averaged markup
  p32_PyPSA_MarkupAvg(t,regi,te)$(tPy32(t) and regPy32(regi) and tePy32(te)) = p32_PyPSA_Markup(t,regi,te);
  !! Activate PyPSA equations
  sm_PyPSA_eq = 1;
$endif

*** EOF ./modules/32_power/PyPSA/preloop.gms
