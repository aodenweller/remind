*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/21_tax/on/bounds.gms
*cb no taxes in 2005, fix budget equation term to zero
vm_taxrev.fx("2005",regi) = 0;

* Deactivate demand-side markup for EVs and AC (for now)
* The electricity price paid by EVs is passed to EDGE-T directly
* The electricity price paid by default load (AC) is not implemented for now
$ifthen.markup_demand "%cm_pypsa_markup_demand%" == "on"
v21_taxrevPyPSAMarkupDemand.fx(t,regi,"EVs")$(tPy32(t) and regPy32(regi)) = 0;
v21_taxrevPyPSAMarkupDemand.fx(t,regi,"AC")$(tPy32(t) and regPy32(regi)) = 0;
$endif.markup_demand

*** EOF ./modules/21_tax/on/bounds.gms
