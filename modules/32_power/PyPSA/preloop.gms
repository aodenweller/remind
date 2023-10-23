*** |  (C) 2006-2023 Potsdam Institute for Climate Impact Research (PIK)
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
p32_PyPSA_ElecPriceAvg(tPy32,regPy32) = 0;
p32_PyPSA_PeakResLoadRel(tPy32,regPy32) = 0;
p32_PyPSA_shSeEl(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_ValueFactor(tPy32,regPy32,tePy32) = 0;
p32_PyPSA_Curtailment(tPy32,regPy32,tePyVRE32) = 0;

*** EOF ./modules/32_power/PyPSA/preloop.gms
