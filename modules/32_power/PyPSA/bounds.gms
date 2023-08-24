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

* Set cm_PyPSA_eq to 1 after the starting iteration of PyPSA
* This is used to activate equations and bounds
if ((iteration.val gt c32_startIter_PyPSA),
  cm_PyPSA_eq = 1;
);

* Read in values after first PyPSA run in previous iteration
if ((cm_pypsa_eq eq 1),
* Capacity factor for coupled dispatchable technologies without grades (tePyDisp32)
$ifthen.c32_pypsa_capfac "%c32_pypsa_capfac%" == "on"
pm_cf(tPy32,regPy32,tePyDisp32) = p32_PyPSA_CF(tPy32,regPy32,tePyDisp32);
$endif.c32_pypsa_capfac

* Capacity factor for VRE technologies (with grades) are set via q32_capFacVRE (equations.gms)
* Bounds for vm_capFac for VRE technologies are set and described below

* Calculate markup and convert to T$/TWa
$ifthen.cm_pypsa_markup "%cm_pypsa_markup%" == "on"
pm_Markup(tPy32,regPy32,tePy32) = ( p32_PyPSA_MV(tPy32,regPy32,tePy32)
                                  - p32_PyPSA_ElecPrice(tPy32,regPy32) )
                                  * sm_TWa_2_MWh / 1e12;
$endif.cm_pypsa_markup

$ifthen.c32_pypsa_curtailment "%c32_pypsa_curtailment%" == "on"
if ((cm_PyPSA_eq eq 1),
  v32_storloss.fx(tPy32,regPy32,tePyVRE32) = p32_PyPSA_Curtailment / sm_TWa_2_MWh;
);
$endif.c32_pypsa_curtailment

$ifthen.c32_pypsa_curtailment "%c32_pypsa_curtailment%" == "off"
if ((cm_PyPSA_eq eq 1),
  v32_storloss.fx(tPy32,regPy32,tePy32) = 0;
);
$endif.c32_pypsa_curtailment

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

* All capacity factors come from PyPSA-Eur.
* For dispatchable technologies, vm_capFac is fixed to pm_cf (see above), which is overwritten with p32_PyPSA_CF in part 1/2.
* (ToDo: Include a pre-factor equation that includes a gradient/slope.)
* For VRE technologies, here we set vm_capFac free so that REMIND can adjust it using equation q32_capFacVRE.
* vm_capFac can be larger than 1 since it is used as a "correction factor" so that the VRE capacity factor equals p32_PyPSA_CF.
$ifthen.c32_pypsa_capfac "%c32_pypsa_capfac%" == "on"
if ((cm_PyPSA_eq eq 1),
  vm_capFac.lo(tPy32,regPy32,tePy32) = 0;
  vm_capFac.up(tPy32,regPy32,tePy32) = 2;
);
$endif.c32_pypsa_capfac

* TEST: Require a minimum of 600 TWh load
v32_usableSeDisp.lo(tPy32,regPy32,"seel") = 600 / 8760;

* v32_shSeElDisp must be between 0 and 1
v32_shSeElDisp.lo(tPy32,regPy32,tePy32) = 0;
v32_shSeElDisp.up(tPy32,regPy32,tePy32) = 1;

*** EOF ./modules/32_power/PyPSA/bounds.gms
