*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/declarations.gms

***------------------------------------------------------------
***                  Declarations copied from IntC
***------------------------------------------------------------

parameters
    p32_grid_factor(all_regi)						"multiplicative factor that scales total grid requirements down in comparatively small or homogeneous regions like Japan, Europe or India"
    p32_gridexp(all_regi,all_te)					"exponent that determines how grid requirement per kW increases with market share of wind and solar. 1 means specific marginal costs increase linearly"
    p32_storexp(all_regi,all_te)					"exponent that determines how curtailment and storage requirements per kW increase with market share of wind and solar. 1 means specific marginal costs increase linearly"
    p32_shCHP(ttot,all_regi)            			"upper boundary of chp electricity generation"
    p32_factorStorage(all_regi,all_te)      		"multiplicative factor that scales total curtailment and storage requirements up or down in different regions for different technologies (e.g. down for PV in regions where high solar radiation coincides with high electricity demand)"
    f32_storageCap(char, all_te)                    "multiplicative factor between dummy seel<-->h2 technologies and storXXX technologies"
    p32_storageCap(all_te,char)                     "multiplicative factor between dummy seel<-->h2 technologies and storXXX technologies"
    p32_PriceDurSlope(all_regi,all_te)              "slope of price duration curve used for calculation of electricity price for flexible technologies, determines how fast electricity price declines at lower capacity factors"
    o32_dispatchDownPe2se(ttot,all_regi,all_te)     "output parameter to check by how much a pe2se te reduced its output below the normal, in % of the normal output."
    p32_shThresholdTotVREAddIntCost(ttot)           "Total VRE share threshold above which additional integration challenges arise. Increases with time as eg in 2030, there is still little experience with managing systems with 80% VRE share. Unit: Percent"
    p32_FactorAddIntCostTotVRE                      "Multiplicative factor that influences how much the total VRE share increases integration challenges"
    p32_phaseInElh2VREcap(ttot)                     "phase-in factor for electrolysis capacities built from stored VRE electricity, scale up from 2030 to 2040"
    p32_flexSeelShare_slope(ttot,all_regi,all_te)   "Slope of relationship between average electricity price for flexible technology and share of this technology in total electricity demand. Unit: [ % percentage of average electricity price / % share in electricity demand]."
;

scalars
s32_storlink                                        "how strong is the influence of two similar renewable energies on each other's storage requirements (1= complete, 4= rather small)" /3/
;

positive variables
    v32_shStor(ttot,all_regi,all_te)         		"share of seel production from a VRE te that needs to be stored based on this te's share. Unit: ~Percent"
    v32_storloss(ttot,all_regi,all_te)         		"total energy loss from storage for a given technology [TWa]"
    vm_shSeEl(ttot,all_regi,all_te)				"new share of electricity production in % [%]"
    v32_testdemSeShare(ttot,all_regi,all_te)        "test variable for tech share of SE electricity demand"
    v32_TotVREshare(ttot,all_regi)                  "Total VRE share as calculated by summing shSeEl. Unit: Percent"
    v32_shAddIntCostTotVRE(ttot,all_regi)           "Variable containing how much the total VRE share is above the threshold - needed to calculate additional integation costs due to total VRE share."
    vm_shDemSeel(ttot,all_regi,all_te)              "Share of electricity demand per technology in total electricity demand"
;

equations
    q32_balSe(ttot,all_regi,all_enty)				"balance equation for electricity secondary energy"
    q32_usableSe(ttot,all_regi,all_enty)			"calculate usable se before se2se and MP/XP (without storage)"
    q32_usableSeTe(ttot,all_regi,entySe,all_te)   	"calculate usable se produced by one technology (vm_usableSeTe)"
    q32_limitCapTeStor(ttot,all_regi,teStor)		"calculate the storage capacity required by vm_storloss"
    q32_limitCapTeChp(ttot,all_regi)                "capacitiy constraint for chp electricity generation"
    q32_limitCapTeGrid(ttot,all_regi)          		"calculate the additional grid capacity required by VRE"
    q32_shSeEl(ttot,all_regi,all_te)         		"calculate share of electricity production of a technology (vm_shSeEl)"
    q32_shStor(ttot,all_regi,all_te)                "equation to calculate v32_shStor"
    q32_storloss(ttot,all_regi,all_te)              "equation to calculate vm_storloss, and - as vm_storloss determines the storage capacity - also the general integration challenges"
    q32_operatingReserve(ttot,all_regi)  			"operating reserve for necessary flexibility"
    q32_h2turbVREcapfromTestor(tall,all_regi)       "calculate capacities of dummy seel<--h2 technology from storXXX technologies"
    q32_h2turbVREcapfromTestorUp(ttot,all_regi)     "constraint h2turbVRE hydrogen turbines to be only built together with storage capacities"
    q32_elh2VREcapfromTestor(tall,all_regi)         "calculate capacities of dummy seel-->h2 technology from storXXX technologies"
    q32_flexAdj(ttot,all_regi,all_te)               "calculate flexibility benefit or cost per flexible technology to be used by flexibility tax"
    q32_flexPriceShareMin(ttot,all_regi,all_te)     "calculate miniumum share of average electricity that flexible technologies can see"
    q32_flexPriceShareVRE(ttot,all_regi,all_te)     "calculate miniumum share of average electricity that flexible technologies can see given the current VRE share"
    q32_flexPriceShare(ttot,all_regi,all_te)        "calculate share of average electricity price that flexible technologies see given a certain VRE share and share of electrolysis in total electricity demand"
    q32_flexPriceBalance(ttot,all_regi)             "constraint such that flexible electricity prices balanance to average electricity price"
    q32_TotVREshare(ttot,all_regi)                  "calculate total VRE share"
    q32_shAddIntCostTotVRE(ttot,all_regi)           "calculate how much total VRE share is above threshold value"
    q32_shDemSeel(ttot,all_regi,all_te)             "calculate share of electricity demand per technology in total electricity demand"
;

variables
v32_flexPriceShare(ttot,all_regi,all_te)            "share of average electricity price that flexible technologies see [share: 0...1]"
v32_flexPriceShareVRE(ttot,all_regi,all_te)         "possible minimum of share of average electricity price that flexible technologies see given the current VRE share [share: 0...1]"   
v32_flexPriceShareMin(ttot,all_regi,all_te)         "possible minimum of share of average electricity price that flexible technologies see [share: 0...1]"

;

***------------------------------------------------------------
***                  Declarations for PyPSA
***------------------------------------------------------------

*** Parameters for the PyPSA coupling. These include the following categories:
*** (1) PyPSA export parameters: Parameters that are written to REMIND2PyPSAEUR.gdx in postsolve.gms
*** (2) PyPSA import parameters: Parameters that are read from PyPSAEUR2REMIND.gdx in postsolve.gms (import calc parameters are derived from these)
*** (3) PyPSA coupling parameters: Parameters that are used within the coupling, mostly in equations.gms
*** (4) PyPSA reporting parameters: Parameters that are calculated for reporting and plotting
parameters
    p32_load(ttot,all_regi)                                         "PyPSA export: Electricity load [TWa]"
    p32_preInvCap(ttot,all_regi,all_te)                             "PyPSA export: Pre-investment capacities [TW for generation/link, TWh for storage]"
    p32_preInvCap_iter(iteration,ttot,all_regi,all_te)              "PyPSA export: Pre-investment capacities in iterations [TW for generation/link, TWh for storage]"
    p32_preInvCapAvg(ttot,all_regi,all_te)                          "PyPSA export: Pre-investment capacities averaged over iterations [TW for generation/link, TWh for storage]"
    p32_discountRate(ttot)                                          "PyPSA export: Interest rate / discount rate aggregated across all regions in regPy32 [1]"
    p32_capCostwAdjCost(ttot,all_regi,all_te)                       "PyPSA export: Specific capital costs plus adjustment costs [T$/TW_out for generation/link, T$/TWh for storage]"
    p32_PEPrice_iter(iteration,ttot,all_regi,all_enty)              "PyPSA export: PE price in iterations [T$/TWa, nuclear: T$/Mt]"
    p32_PEPriceAvg(ttot,all_regi,all_enty)                          "PyPSA export: PE price averaged over iterations [T$/TWa, nuclear: T$/Mt]"
    p32_ElecH2Demand(ttot,all_regi)                                 "PyPSA export: Electrolytic hydrogen demand outside the power sector [TWa]"
    p32_weightGen(ttot,all_regi,all_te)                             "PyPSA export: Weights for generation technologies [TWa]"
    p32_weightStor(ttot,all_regi,all_te)                            "PyPSA export: Weights for storage technologies, currently electrolysis and hydrogen turbines [TWa]"
    p32_weightPEprice(ttot,all_regi,all_enty)                       "PyPSA export: Weights for primary energy prices [TWa]"
    p32_hydroCap(ttot,all_regi)                                     "PyPSA export: Hydro capacity [TW]"
    p32_hydroGen(ttot,all_regi)                                     "PyPSA export: Hydro generation [TWa]"
    p32_PyPSA_CF(ttot,all_regi,all_te)                              "PyPSA import: Capacity factors [1]"
    p32_PyPSA_CF_iter(iteration,ttot,all_regi,all_te)               "PyPSA import calc: Capacity factors in iterations [1]"
    p32_PyPSA_CFAvg(ttot,all_regi,all_te)                           "PyPSA import calc: Capacity factors averaged over iterations [1]"
    p32_PyPSA_MV(ttot,all_regi,all_te)                              "PyPSA import: Market values [$/MWh]"
    p32_PyPSA_MV_iter(iteration,ttot,all_regi,all_te)               "PyPSA import calc: Market values in iterations [1]" 
    p32_PyPSA_MVAvg(ttot,all_regi,all_te)                           "PyPSA import calc: Market values averaged over iterations [$/MWh]"
    p32_PyPSA_LoadPrice(ttot,all_regi,carrierPy32)                  "PyPSA import: Generic load prices (currently for electricity and hydrogen, later also sectoral loads) [$/MWh]"
    p32_PyPSA_LoadPrice_iter(iteration,ttot,all_regi,carrierPy32)   "PyPSA import calc: Load prices in iterations [$/MWh]"
    p32_PyPSA_LoadPriceAvg(ttot,all_regi,carrierPy32)               "PyPSA import calc: Load prices averaged over iterations [$/MWh]"
    p32_PyPSA_Markup(ttot,all_regi,all_te)                          "PyPSA import: Markups for electricity technologies according to PyPSA-Eur [$/MWh]"
    p32_PyPSA_Markup_iter(iteration,ttot,all_regi,all_te)           "PyPSA import calc: Markups in iterations [$/MWh]"
    p32_PyPSA_MarkupAvg(ttot,all_regi,all_te)                       "PyPSA import calc: Markups averaged over iterations [$/MWh]"
    p32_PyPSA_Curtailment(ttot,all_regi,all_te)                     "PyPSA import: Curtailment by technology [MWh]"
    p32_PyPSA_PeakResLoadRel(ttot,all_regi)                         "PyPSA import: Peak residual load relative to average load [1]"
    p32_PyPSA_shSeEl(ttot,all_regi,all_te)                          "PyPSA import: Electricity generation share by technology within region [1]"
    p32_PyPSA_ValueFactor(ttot,all_regi,all_te)                     "PyPSA import calc: Value factor = Market value / electricity price [1]"
    p32_PyPSA_StoreTrans_Cap(ttot,all_regi,storeTransPy32)          "PyPSA import: Storage and transmission capacities [MW] (links, lines) or [MWh] (stores). Attention: w.r.t. input!"
    p32_PyPSA_StoreTrans_CF(ttot,all_regi,storeTransPy32)           "PyPSA import: Storage and transmission capacity factors [1]"
    p32_PyPSA_H2TurbRel(ttot,all_regi)                              "PyPSA import: Hydrogen turbine supply relative to total load [1]"
    p32_PyPSA_Trade(ttot,all_regi,all_regi)                         "PyPSA import: Electricity exports from region 1 to region 2 [MWh]" 
    p32_PyPSA_TradePriceImport(ttot,all_regi,all_regi)              "PyPSA import: Price for electricity imports paid by region 2 due to trade with region 1 [$/MWh]"
    p32_PyPSA_TradePriceExport(ttot,all_regi,all_regi)              "PyPSA import: Price for electricity exports received by region 1 due to trade with region 2 [$/MWh]"
    p32_PyPSA_Potential(ttot,all_regi,all_te)                       "PyPSA import: VRE potentials by technology within region [MW]"
    p32_PyPSA_shSeElRegi(ttot,all_regi)                             "PyPSA import: Electricity generation share across coupled regions [1]"
    p32_PyPSA_AF(ttot,all_regi,all_te)                              "PyPSA import: Availability factors [1]"
    p32_PyPSA_ElecPriceElectrolysis(ttot,all_regi)                  "PyPSA import: Electricity price paid by electrolysis [$/MWh]"
    p32_PyPSA_ElecPriceElectrolysis_iter(iteration,ttot,all_regi)   "PyPSA import calc: Electricity price paid by electrolysis in iterations [$/MWh]"
    p32_PyPSA_ElecPriceElectrolysisAvg(ttot,all_regi)               "PyPSA import calc: Electricity price paid by electrolysis averaged over iterations [$/MWh]"
    p32_gridLossesRel(ttot,all_regi)                                "PyPSA import: Transmission losses relative to total load [1]"
    p32_preFactor_CF(all_regi,all_te)                               "PyPSA coupling: Pre-factor for the capacity factor [1]"
    p32_preFactor_MV(all_regi,all_te)                               "PyPSA coupling: Pre-factor for the market value [1]"
    p32_usableSeDispForeign(ttot,all_regi)                          "PyPSA coupling: Foreign usable SE electricity generation, without own consumption, without imports/exports [TWa]"
    p32_hydroCorrectionFactor(ttot,all_regi)                        "PyPSA coupling: Hydro correction factor, defined as availability factor / capacity factor of previous iteration [1]"
    sm_PyPSA_eq                                                     "PyPSA coupling: Boolean that activates PyPSA coupling equations (1 = on, 0 = off)"
    s32_checkPrice                                                  "PyPSA coupling: Boolean that checks if budget equation is binding (1 = yes, 0 = no)"
    s32_checkPrice_iter(iteration)                                  "PyPSA coupling: s32_checkPrice in iterations"
    s32_preFacFadeOut                                               "PyPSA coupling: Multiplicative factor to fade out pre-factors [1]"
    s32_PyPSA_called(iteration)                                     "PyPSA coupling: Boolean that tracks if PyPSA was called over iterations, necessary for averaging (1 = yes, 0 = no)"
    p32_PeakResLoadShadowPrice(ttot,all_regi,all_te)                "PyPSA reporting: Shadow price of peak residual load constraint, used for plotting LCOEs vs. market values [T$/TWa]"
    p32_ElecBalance(ttot,all_regi,rep32)                            "PyPSA reporting: Electricity balance [TWa]"
;

*** Positive variables for the PyPSA coupling
positive variables
    v32_load(ttot,all_regi)                                         "PyPSA coupling: Electricity load [TWa]"
    v32_usableSeDisp(ttot,all_regi,all_enty)                        "PyPSA coupling: Domestic usable SE electricity generation, without own consumption, without imports/exports [TWa]"
    v32_usableSeTeDisp(ttot,all_regi,all_enty,all_te)               "PyPSA export: Domestic usable SE electricity generation, without own consumption, without imports/exports, by technology [TWa]"
    v32_shSeElDisp(ttot,all_regi,all_te)                            "PyPSA export/coupling: Share of domestic usable SE electricity generation, without own consumption, used for pre-factor equations [1]"
    v32_gridLosses(ttot,all_regi)                                   "PyPSA coupling: Grid losses [TWa]"
$ifthen "%c32_pypsa_trade%" == "on"
    v32_shSeElRegi(ttot,all_regi)                                   "PyPSA coupling: Share of usable SE electricity for dispatch without own consumption by region [1]"
    v32_shSeELTradeImport(ttot,all_regi)                            "PyPSA coupling: Share of electricity imports relative to domestic production [1]"
    v32_shSeELTradeExport(ttot,all_regi)                            "PyPSA coupling: Share of electricity exports relative to domestic production [1]"
$endif
;

*** Variables for the PyPSA coupling
$ifthen "%cm_pypsa_markup%" == "on"
variables
    vm_PyPSAMarkup(ttot,all_regi,all_te)                            "PyPSA coupling: Markups for electricity generation technologies  [T$/TWa]"
    vm_PyPSAMarkupDemand(ttot,all_regi,all_te)                      "PyPSA coupling: Markups for electricity consumption technologies [T$/TWa]"
;
$endif

*** Equations for the PyPSA coupling
equations
    q32_load(ttot,all_regi,all_enty)                                "PyPSA coupling: Calculate electricity load"
    q32_usableSeDisp(ttot,all_regi,all_enty)                        "PyPSA coupling: Calculate v32_usableSeDisp"
    q32_usableSeTeDisp(ttot,all_regi,all_enty,all_te)               "PyPSA coupling: Calculate v32_usableSeTeDisp"
    q32_shSeElDisp(ttot,all_regi,all_te)                            "PyPSA coupling: Calculate v32_shSeElDisp"
$ifthen "%c32_pypsa_capfac%" == "on"
    q32_capFac(ttot,all_regi,all_te)                                "PyPSA coupling: Pre-factor equation for capacity factors"
$endif
$ifthen "%cm_pypsa_markup%" == "on"
    q32_MarkUp(ttot,all_regi,all_te)                                "PyPSA coupling: Pre-factor equation to calculate technology-specific markups"
    q32_MarkUpDemand(ttot,all_regi,all_te)                          "PyPSA coupling: Equation for markup demand"
$endif
$ifthen "%c32_pypsa_peakcap%" == "on"
    q32_PeakResCap(ttot,all_regi)                                   "PyPSA coupling: Pre-factor equation for peak residual load"
$endif
$ifthen "%c32_pypsa_trade%" == "on"
    q32_shSeElRegi(ttot,all_regi)                                   "PyPSA coupling: Calculate v32_shSeElRegi"
    q32_TradeImport(ttot,all_regi)                                  "PyPSA coupling: Pre-factor equation for electricity trade import"
    q32_TradeExport(ttot,all_regi)                                  "PyPSA coupling: Pre-factor equation for electricity trade export"
    q32_shSeELTradeImport(ttot,all_regi)                            "PyPSA coupling: Calculate v32_shSeELTradeImport"
    q32_shSeELTradeExport(ttot,all_regi)                            "PyPSA coupling: Calculate v32_shSeELTradeExport"
$endif
$ifthen "%c32_pypsa_h2stor%" == "on"
    q32_h2turb(ttot,all_regi)                                       "PyPSA coupling: Equation for hydrogen turbine supply requirements"
    q32_elh2forh2turb(ttot,all_regi)                                "PyPSA coupling: Equation requiring electrolysis production for hydrogen turbines"
$endif
    q32_gridLosses(ttot,all_regi)                                   "PyPSA coupling: Equation to calculate grid losses"
;

*** EOF ./modules/32_power/PyPSA/declarations.gms
