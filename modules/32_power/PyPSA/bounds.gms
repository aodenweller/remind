*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/bounds.gms

***------------------------------------------------------------
***                  PyPSA-Eur coupling (data import))
***------------------------------------------------------------

* Read in values after first PyPSA run in previous iteration
if ((sm_PyPSA_eq eq 1),

* Capacity factors: Overwrite pm_cf for dispatchable technologies
* This is probably redundant as vm_capfac is not fixed to pm_cf any longer, but free
* ToDo: Check capacity factor reporting, maybe set pm_cf = vm_capfac.l in postsolve for reporting
$ifthen "%c32_pypsa_capfac%" == "on"
  pm_cf(tPy32,regPy32,tePyDisp32) = p32_PyPSA_CFAvg(tPy32,regPy32,tePyDisp32);
$endif

* Read in curtailment at some point?
$ifthen "%c32_pypsa_curtailment%" == "on"
  v32_storloss.fx(tPy32,regPy32,tePyVRE32) = p32_PyPSA_Curtailment(tPy32,regPy32,tePyVRE32) / sm_TWa_2_MWh;
$else
  v32_storloss.fx(tPy32,regPy32,tePy32) = 0;
$endif

* Calculate value factor to parametrise the pre-factor equation for markups
$ifthen "%cm_pypsa_markup%" == "on"
  p32_PyPSA_ValueFactor(tPy32,regPy32,tePy32) = p32_PyPSA_MVAvg(tPy32,regPy32,tePy32) / p32_PyPSA_LoadPriceAvg(tPy32,regPy32,"AC");
$endif

);

***------------------------------------------------------------
***                  Bounds copied from IntC
***------------------------------------------------------------

*** Fix capacity factors to the standard value from data
vm_capFac.fx(t,regi,te) = pm_cf(t,regi,te);

$IFTHEN.dispatchSetyDown not "%cm_dispatchSetyDown%" == "off"
  loop(pe2se(enty,enty2,te),
    vm_capFac.lo(t,regi,te) = ( 1 - %cm_dispatchSetyDown% / 100 ) * pm_cf(t,regi,te);
  );
$ENDIF.dispatchSetyDown

$IFTHEN.dispatchSeelDown not "%cm_dispatchSeelDown%" == "off"
  loop(pe2se(enty,enty2,te)$sameas(enty2,"seel"),  
    vm_capFac.lo(t,regi,te) = ( 1 - %cm_dispatchSeelDown% / 100 ) * pm_cf(t,regi,te);  
  );
$ENDIF.dispatchSeelDown


*** FS: if flexibility tax on, let capacity factor be endogenuously determined between 0.1 and 1 
*** for technologies that get flexibility tax/subsity (teFlexTax)
if ( cm_flex_tax eq 1,
  if ( cm_FlexTaxFeedback eq 1,
*** if flexibility tax feedback is on, let model choose capacity factor of flexible technologies freely
	  vm_capFac.lo(t,regi,teFlexTax)$(t.val ge 2010) = 0.1;
    vm_capFac.up(t,regi,teFlexTax)$(t.val ge 2010) = pm_cf(t,regi,teFlexTax);
  else 
*** if flexibility tax feedback is off, only flexibliity tax benefit for flexible technologies and 0.5 capacity factor
    vm_capFac.fx(t,regi,teFlex)$(t.val ge 2010) = 0.5;
*** electricity price of inflexible technologies the same w/o feedback
    v32_flexPriceShare.fx(t,regi,te)$(teFlexTax(te) AND NOT(teFlex(te))) = 1;
  );
);

*** Lower bounds on VRE use (more than 0.01% of electricity demand) after 2015 to prevent the model from overlooking solar and wind
loop(regi,
  loop(te$(teVRE(te)),
    if ( (sum(rlf, pm_dataren(regi,"maxprod",rlf,te)) > 0.01 * pm_IO_input(regi,"seel","feels","tdels")) ,
         vm_shSeEl.lo(t,regi,te)$(t.val>2020) = 0.01; 
    );
  );
);

*RP* upper bound of 90% on share of electricity produced by a single VRE technology, and lower bound on usablese to prevent the solver from dividing by 0
vm_shSeEl.up(t,regi,teVRE) = 90;

vm_usableSe.lo(t,regi,"seel")  = 1e-6;

*** Fix capacity for h2curt technology (modeled only in RLDC)
vm_cap.fx(t,regi,"h2curt",rlf) = 0;


*RP To ensure that the REMIND model doesn't overlook CSP due to gdx effects, ensure some minimum use in regions with good solar insolation, here proxied from the csp storage factor:
loop(regi$(p32_factorStorage(regi,"csp") < 1),
  vm_shSeEl.lo(t,regi,"csp")$(t.val > 2025) = 0.5;
  vm_shSeEl.lo(t,regi,"csp")$(t.val > 2050) = 1;
  vm_shSeEl.lo(t,regi,"csp")$(t.val > 2100) = 2;
);

*** Fix capacity to 0 for elh2VRE now that the equation q32_elh2VREcapfromTestor pushes elh2, not anymore elh2VRE, and capital costs are 1
vm_cap.fx(t,regi,"elh2VRE",rlf) = 0;

***------------------------------------------------------------
***                  PyPSA-Eur coupling (bounds)
***------------------------------------------------------------

*** All capacity factors come from PyPSA-Eur.
*** Set vm_capFac free here, so that REMIND can adjust it freely to match the capacity factor from PyPSA-Eur (equation q32_capFac).
*** vm_capFac can be larger than 1 since it is used as a correction factor. Limit to between 0 and 2 here.
$ifthen "%c32_pypsa_capfac%" == "on"
if ((sm_PyPSA_eq eq 1),
  vm_capFac.lo(tPy32,regPy32,tePy32)$(not sameas(tePy32,"hydro")) = 0;
  vm_capFac.up(tPy32,regPy32,tePy32)$(not sameas(tePy32,"hydro")) = 2;
);
$endif

*** Restrict v32_shSeElDisp between 0 and 1
v32_shSeElDisp.lo(tPy32,regPy32,tePy32) = 0;
v32_shSeElDisp.up(tPy32,regPy32,tePy32) = 1;

*** Temporarily fix hydro markup to zero
$ifthen "%cm_pypsa_markup%" == "on"
vm_PyPSAMarkup.fx(tPy32,regPy32,"hydro") = 0;
$endif

*** Disable some technologies for now
if ((c32_deactivateTech eq 1 and sm_PyPSA_eq eq 1),
    vm_shSeEl.fx(tPy32,regPy32,"csp") = 0;  !! Overwrite RP's hotfix above
    vm_capFac.fx(tPy32,regPy32,"csp") = 0;
    vm_capFac.fx(tPy32,regPy32,"geohdr") = 0;
    vm_capFac.fx(tPy32,regPy32,"biochp") = 0;
    vm_capFac.fx(tPy32,regPy32,"gaschp") = 0;
    vm_capFac.fx(tPy32,regPy32,"coalchp") = 0;
);

*** Electricity trade
$ifthen "%c32_pypsa_trade%" == "on"
if ((sm_PyPSA_eq eq 1),
  !! Set bounds for vm_Mport and vm_Xport
  vm_Mport.lo(tPy32,regPy32,"seel") = 0;
  vm_Mport.up(tPy32,regPy32,"seel") = Inf;
  vm_Xport.lo(tPy32,regPy32,"seel") = 0;
  vm_Xport.up(tPy32,regPy32,"seel") = Inf;
  !! Set starting values for vm_Mport and vm_Xport
  !! This seems strictly necessary because otherwise the solver will simply set both to 0
  vm_Mport.l(tPy32,regPy32,"seel") = sum(regPy32_2, p32_PyPSA_ElecTrade(tPy32,regPy32_2,regPy32)) / sm_TWa_2_MWh;
  vm_Xport.l(tPy32,regPy32,"seel") = sum(regPy32_2, p32_PyPSA_ElecTrade(tPy32,regPy32,regPy32_2)) / sm_TWa_2_MWh;
  !! Restrict v32_shSeElRegi between 0 and 1
  v32_shSeElRegi.lo(tPy32,regPy32) = 0;
  v32_shSeElRegi.up(tPy32,regPy32) = 1;
  !! ToDO: Also get pm_MPortsPrice and pm_XPortsPrice from PyPSA-Eur
  !! pm_MPortsPrice(tPy32,regPy32,"seel") = p32_PyPSA...;
  !! pm_XPortsPrice(tPy32,regPy32,"seel") = p32_PyPSA...;
);
$endif

*** EOF ./modules/32_power/PyPSA/bounds.gms
