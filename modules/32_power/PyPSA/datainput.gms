*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/datainput.gms

***------------------------------------------------------------
***                  Data input copied from IntC
***------------------------------------------------------------

parameter f32_shCHP(ttot,all_regi) "upper boundary of chp electricity generation"
/
$ondelim
$include "./modules/32_power/IntC/input/f32_shCHP.cs4r"
$offdelim
/
;
p32_shCHP(ttot,all_regi) = f32_shCHP(ttot,all_regi) + 0.05;
p32_shCHP(ttot,all_regi)$(ttot.val ge 2050) = min(p32_shCHP("2020",all_regi) + 0.15, 0.75);
p32_shCHP(ttot,all_regi)$((ttot.val gt 2020) and (ttot.val lt 2050)) = p32_shCHP("2020",all_regi) + ((p32_shCHP("2050",all_regi) - p32_shCHP("2020",all_regi)) / 30 * (ttot.val - 2020));

parameter p32_grid_factor(all_regi) "multiplicative factor that scales total grid requirements down in comparatively small or homogeneous regions like Japan, Europe or India"
/
$ondelim
$include "./modules/32_power/IntC/input/p32_grid_factor.cs4r"
$offdelim
/
;

parameter f32_factorStorage(all_regi,all_te) "multiplicative factor that scales total curtailment and storage requirements up or down in different regions for different technologies (e.g. down for PV in regions where high solar radiation coincides with high electricity demand)"
/
$ondelim
$include "./modules/32_power/IntC/input/f32_factorStorage.cs4r"
$offdelim
/
;

*** windoffshore-todo
*** allow input data with either "wind" or "windon" until mrremind is updated 
f32_factorStorage(all_regi,"windon") $ (f32_factorStorage(all_regi,"windon") eq 0) = f32_factorStorage(all_regi,"wind");
f32_factorStorage(all_regi,"windoff") = f32_factorStorage(all_regi,"windon");
f32_factorStorage(all_regi,"windon")  = 1.35 * f32_factorStorage(all_regi,"windon"); 

p32_factorStorage(all_regi,teVRE) = f32_factorStorage(all_regi,teVRE);

$if not "%cm_storageFactor%" == "off" p32_factorStorage(all_regi,all_te)=%cm_storageFactor%*p32_factorStorage(all_regi,all_te);

***parameter p32_storexp(all_regi,all_te) - exponent that determines how curtailment and storage requirements per kW increase with market share of wind and solar. 1 means specific marginal costs increase linearly
p32_storexp(regi,teVRE) = 1;
***parameter p32_gridexp(all_regi,all_te) - exponent that determines how grid requirement per kW increases with market share of wind and solar. 1 means specific marginal costs increase linearly
p32_gridexp(regi,teVRE) = 1;


table f32_storageCap(char, all_te) "multiplicative factor between dummy seel<-->h2 technologies and storXXX technologies"
$include "./modules/32_power/IntC/input/f32_storageCap.prn"
;

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

*** Flexibility Tax Parameter

*** Both flexibility tax parameters are based on a regression analysis with hourly dispatch data from high-VRE scenarios of the Langfristszenarien
*** for Germany provided by the Enertile power system model.
*** See: https://langfristszenarien.de/enertile-explorer-de/szenario-explorer/angebot.php

*** This parameter determines by the maximum electricity price reduction for electrolysis at 100% VRE share and 0% share of electrolysis in total electricity demand.
*** Standard value is derived based on the regression of the German Langfristzenarien.
parameter f32_cm_PriceDurSlope_elh2(ext_regi) "slope of price duration curve for electrolysis [#]" / %cm_PriceDurSlope_elh2% /;
p32_PriceDurSlope(regi,"elh2") = f32_cm_PriceDurSlope_elh2("GLO");
loop(ext_regi$f32_cm_PriceDurSlope_elh2(ext_regi),
  loop(regi$regi_groupExt(ext_regi,regi),
    p32_PriceDurSlope(regi,"elh2") = f32_cm_PriceDurSlope_elh2(ext_regi);
  );
); 

*** Slope of increase of electricity price for electrolysis with increasing share of electrolysis in power system
*** The value of 1.1 is derived from the regression of the German Langfristzenarien.
p32_flexSeelShare_slope(t,regi,"elh2") = 1.1;

*** Elh2VREcap phase-in factor
p32_phaseInElh2VREcap(t)$(t.val < 2030) = 0;
p32_phaseInElh2VREcap("2030") = 0.25;
p32_phaseInElh2VREcap("2035") = 0.5;
p32_phaseInElh2VREcap(t)$(t.val > 2035) = 1;


***------------------------------------------------------------
***                  PyPSA-Eur
***------------------------------------------------------------

*** Technology-specific anticipation factor values for capacity factors
p32_anticipation_CF(tPy32,"DEU","biochp") = -0.5;
p32_anticipation_CF(tPy32,"DEU","bioigcc") = -0.5;
p32_anticipation_CF(tPy32,"DEU","bioigccc") = -0.5;
p32_anticipation_CF(tPy32,"DEU","ngcc") = -1;
p32_anticipation_CF(tPy32,"DEU","ngccc") = -1;
p32_anticipation_CF(tPy32,"DEU","gaschp") = -1;
p32_anticipation_CF(tPy32,"DEU","igcc") = -2;
p32_anticipation_CF(tPy32,"DEU","igccc") = -2;
p32_anticipation_CF(tPy32,"DEU","pc") = -2;
p32_anticipation_CF(tPy32,"DEU","coalchp") = -2;
p32_anticipation_CF(tPy32,"DEU","tnrs") = 0.2;
p32_anticipation_CF(tPy32,"DEU","fnrs") = 0.2;
p32_anticipation_CF(tPy32,"DEU","ngt") = -1;
p32_anticipation_CF(tPy32,"DEU","dot") = 0;
p32_anticipation_CF(tPy32,"DEU","hydro") = 0;
p32_anticipation_CF(tPy32,"DEU","windoff") = -0.4;
p32_anticipation_CF(tPy32,"DEU","windon") = -0.4;
p32_anticipation_CF(tPy32,"DEU","spv") = -0.4;

*** Technology-specific anticipation factor values for market values
p32_anticipation_MV("DEU","biochp") = -4;
p32_anticipation_MV("DEU","bioigcc") = -4;
p32_anticipation_MV("DEU","bioigccc") = -4;
p32_anticipation_MV("DEU","ngcc") = -8;
p32_anticipation_MV("DEU","ngccc") = -8;
p32_anticipation_MV("DEU","gaschp") = -8;
p32_anticipation_MV("DEU","igcc") = -5;
p32_anticipation_MV("DEU","igccc") = -5;
p32_anticipation_MV("DEU","pc") = -5;
p32_anticipation_MV("DEU","coalchp") = -5;
p32_anticipation_MV("DEU","tnrs") = -1;
p32_anticipation_MV("DEU","fnrs") = -1;
p32_anticipation_MV("DEU","ngt") = -8;
p32_anticipation_MV("DEU","windoff") = -0.5;
p32_anticipation_MV("DEU","dot") = -2;
p32_anticipation_MV("DEU","windon") = -0.5;
p32_anticipation_MV("DEU","hydro") = -1;
p32_anticipation_MV("DEU","spv") = -0.5;

*** Write efficiencies into pm_eta_conv for btin and btout
*** This is necessary, because in 05_initialCap/on/preloop.gms
*** this is only set if cm_startyear eq 2005 and otherwise read in from input_ref
loop(regi,
    pm_eta_conv(ttot,regi,"btin") = pm_data(regi,"eta","btin");
    pm_eta_conv(ttot,regi,"btout") = pm_data(regi,"eta","btout");
    );

*** EOF ./modules/32_power/PyPSA/datainput.gms
