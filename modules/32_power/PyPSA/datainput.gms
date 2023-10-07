*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/datainput.gms

***------------------------------------------------------------
***                  Data input copied from IntC
***------------------------------------------------------------

parameter f32_shCHP(ttot,all_regi)  "upper boundary of chp electricity generation"
/
$ondelim
$include "./modules/32_power/IntC/input/f32_shCHP.cs4r"
$offdelim
/
;
p32_shCHP(ttot,all_regi) = f32_shCHP(ttot,all_regi) + 0.05;
p32_shCHP(ttot,all_regi)$(ttot.val ge 2050) = min(p32_shCHP("2020",all_regi) + 0.15, 0.75);
p32_shCHP(ttot,all_regi)$((ttot.val gt 2020) and (ttot.val lt 2050)) = p32_shCHP("2020",all_regi) + ((p32_shCHP("2050",all_regi) - p32_shCHP("2020",all_regi)) / 30 * (ttot.val - 2020));

***parameter p32_grid_factor(all_regi) - multiplicative factor that scales total grid requirements down in comparatively small or homogeneous regions like Japan, Europe or India
parameter p32_grid_factor(all_regi)                "multiplicative factor that scales total grid requirements down in comparatively small or homogeneous regions like Japan, Europe or India"
/
$ondelim
$include "./modules/32_power/IntC/input/p32_grid_factor.cs4r"
$offdelim
/
;

***parameter p32_factorStorage(all_regi,all_te) - multiplicative factor that scales total curtailment and storage requirements up or down in different regions for different technologies (e.g. down for PV in regions where high solar radiation coincides with high electricity demand)
parameter f32_factorStorage(all_regi,all_te)                  "multiplicative factor that scales total curtailment and storage requirements up or down in different regions for different technologies (e.g. down for PV in regions where high solar radiation coincides with high electricity demand)"
/
$ondelim
$include "./modules/32_power/IntC/input/f32_factorStorage.cs4r"
$offdelim
/
;

$IFTHEN.WindOff %cm_wind_offshore% == "1"
f32_factorStorage(all_regi,"windoff") = f32_factorStorage(all_regi,"wind");
f32_factorStorage(all_regi,"wind")      = 1.35 * f32_factorStorage(all_regi,"wind"); 
$ENDIF.WindOff
p32_factorStorage(all_regi,all_te) = f32_factorStorage(all_regi,all_te);

$if not "%cm_storageFactor%" == "off" p32_factorStorage(all_regi,all_te)=%cm_storageFactor%*p32_factorStorage(all_regi,all_te);

***parameter p32_storexp(all_regi,all_te) - exponent that determines how curtailment and storage requirements per kW increase with market share of wind and solar. 1 means specific marginal costs increase linearly
p32_storexp(regi,"spv")     = 1;
p32_storexp(regi,"csp")     = 1;
p32_storexp(regi,"wind")    = 1;
$IFTHEN.WindOff %cm_wind_offshore% == "1"
p32_storexp(regi,"windoff")    = 1;
$ENDIF.WindOff


***parameter p32_gridexp(all_regi,all_te) - exponent that determines how grid requirement per kW increases with market share of wind and solar. 1 means specific marginal costs increase linearly
p32_gridexp(regi,"spv")     = 1;
p32_gridexp(regi,"csp")     = 1;
p32_gridexp(regi,"wind")    = 1;


table f32_storageCap(char, all_te)  "multiplicative factor between dummy seel<-->h2 technologies and storXXX technologies"
$include "./modules/32_power/IntC/input/f32_storageCap.prn"
;

$IFTHEN.WindOff %cm_wind_offshore% == "1"
f32_storageCap(char,"windoff") = f32_storageCap(char,"wind");
$ENDIF.WindOff 

p32_storageCap(te,char) = f32_storageCap(char,te);
display p32_storageCap;

*** set total VRE share threshold above which additional integration challenges arise: 
p32_shThresholdTotVREAddIntCost(t)$(t.val < 2030) = 50;
p32_shThresholdTotVREAddIntCost("2030") = 60;
p32_shThresholdTotVREAddIntCost("2035") = 70;
p32_shThresholdTotVREAddIntCost("2040") = 80;
p32_shThresholdTotVREAddIntCost("2045") = 90;
p32_shThresholdTotVREAddIntCost(t)$(t.val > 2045) = 95;

p32_FactorAddIntCostTotVRE = 1.5;

$ontext
parameter p32_flex_maxdiscount(all_regi,all_te) "maximum electricity price discount for flexible technologies reached at high VRE shares"
/
$ondelim
$include "./modules/32_power/IntC/input/p32_flex_maxdiscount.cs4r"
$offdelim
/
; 
*** convert from USD2015/MWh to trUSD2005/TWa
p32_flex_maxdiscount(regi,te) = p32_flex_maxdiscount(regi,te) * sm_TWa_2_MWh * sm_D2015_2_D2005 * 1e-12;
display p32_flex_maxdiscount;
$offtext

*** initialize p32_PriceDurSlope parameter
p32_PriceDurSlope(regi,"elh2") = cm_PriceDurSlope_elh2;

***------------------------------------------------------------
***                  PyPSA-Eur
***------------------------------------------------------------

*** Hydro: Pumped hydro storage (PHS) capacity and generation values in 2020
*** This is necessary because PyPSA doesn't include PHS as a generation technology
if (c32_PHSsubtract eq 1,
  p32_iniCapPHS("DEU","hydro") = 5.3E-3;  !! 5.3 GW 
  p32_iniProdPHS("DEU","hydro") = 6.1/8760;  !! 6.1 TWh/yr
elseif (c32_PHSsubtract eq 0),
  p32_iniCapPHS("DEU", "hydro") = 0;
  p32_iniProdPHS("DEU", "hydro") = 0;
);

*** Technology-specific pre-factor values for capacity factors
p32_preFactor_CF("DEU","biochp") = 2;
p32_preFactor_CF("DEU","bioigcc") = 2;
p32_preFactor_CF("DEU","bioigccc") = 2;
p32_preFactor_CF("DEU","ngcc") = -0.2;
p32_preFactor_CF("DEU","ngccc") = -0.2;
p32_preFactor_CF("DEU","gaschp") = -0.2;
p32_preFactor_CF("DEU","igcc") = 0.2;
p32_preFactor_CF("DEU","igccc") = 0.2;
p32_preFactor_CF("DEU","pc") = 0.2;
p32_preFactor_CF("DEU","coalchp") = 0.2;
p32_preFactor_CF("DEU","tnrs") = 0.2;
p32_preFactor_CF("DEU","fnrs") = 0.2;
p32_preFactor_CF("DEU","ngt") = -0.2;
p32_preFactor_CF("DEU","windoff") = -0.3;
p32_preFactor_CF("DEU","dot") = 0.5;
p32_preFactor_CF("DEU","wind") = -0.3;
p32_preFactor_CF("DEU","hydro") = 0;
p32_preFactor_CF("DEU","spv") = -0.3;

*** Technology-specific pre-factor values for market values
p32_preFactor_MV("DEU","biochp") = -4;
p32_preFactor_MV("DEU","bioigcc") = -4;
p32_preFactor_MV("DEU","bioigccc") = -4;
p32_preFactor_MV("DEU","ngcc") = -0.5;
p32_preFactor_MV("DEU","ngccc") = -0.5;
p32_preFactor_MV("DEU","gaschp") = -0.5;
p32_preFactor_MV("DEU","igcc") = -1;
p32_preFactor_MV("DEU","igccc") = -1;
p32_preFactor_MV("DEU","pc") = -1;
p32_preFactor_MV("DEU","coalchp") = -1;
p32_preFactor_MV("DEU","tnrs") = -1;
p32_preFactor_MV("DEU","fnrs") = -1;
p32_preFactor_MV("DEU","ngt") = -0.5;
p32_preFactor_MV("DEU","windoff") = -0.5;
p32_preFactor_MV("DEU","dot") = -2;
p32_preFactor_MV("DEU","wind") = -0.5;
p32_preFactor_MV("DEU","hydro") = -1;
p32_preFactor_MV("DEU","spv") = -0.5;


*** EOF ./modules/32_power/PyPSA/datainput.gms
