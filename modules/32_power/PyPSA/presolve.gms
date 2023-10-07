*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/presolve.gms

***------------------------------------------------------------
***                  Presolve copied from IntC
***------------------------------------------------------------

*** calculation of SE electricity price (useful for internal use and reporting purposes)
pm_SEPrice(t,regi,entySE)$(    abs(qm_budget.m(t,regi)) gt sm_eps
                           AND sameas(entySE,"seel") )
  = q32_balSe.m(t,regi,entySE)
  / qm_budget.m(t,regi);


***------------------------------------------------------------
***                  PyPSA coupling
***------------------------------------------------------------

*** Render validation RMarkdown file
*** Don't put in postsolve.gms because fulldata_i.gdx is only written afterwards

if ((iteration.val ge (c32_startIter_PyPSA + 1)),
  Put_utility logfile, "Exec" /
  "sbatch RenderREMIND-PyPSA-Eur_Validation.sh";

  !! Overwrite deactivated equations with zeros to avoid confusion
  !! Otherwise, these contain the numbers from the previous iteration
  q32_limitCapTeStor.l(t,regi,teStor)$(tPy32(t) and regPy32(regi)) = 0;
  q32_limitCapTeStor.m(t,regi,teStor)$(tPy32(t) and regPy32(regi)) = 0;
  q32_h2turbVREcapfromTestor.l(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_h2turbVREcapfromTestor.m(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_h2turbVREcapfromTestorUp.l(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_h2turbVREcapfromTestor.m(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_limitCapTeGrid.l(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_limitCapTeGrid.m(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_shStor.l(t,regi,teVRE)$(tPy32(t) and regPy32(regi)) = 0;
  q32_shStor.m(t,regi,teVRE)$(tPy32(t) and regPy32(regi)) = 0;
  q32_storloss.l(t,regi,teVRE)$(tPy32(t) and regPy32(regi)) = 0;
  q32_storloss.m(t,regi,teVRE)$(tPy32(t) and regPy32(regi)) = 0;
  q32_TotVREshare.l(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_TotVREshare.m(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_shAddIntCostTotVRE.l(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_shAddIntCostTotVRE.m(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_operatingReserve.l(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
  q32_operatingReserve.m(t,regi)$(tPy32(t) and regPy32(regi)) = 0;
);

if((c32_iterPreFacFadeOut ne 0) and (iteration.val ge c32_iterPreFacFadeOut),
 s32_preFacFadeOut = 0.7**(iteration.val - c32_iterPreFacFadeOut + 1);
);

*** EOF ./modules/32_power/PyPSA/presolve.gms
