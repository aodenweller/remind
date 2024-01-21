*** |  (C) 2006-2022 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/sets.gms

***------------------------------------------------------------
***                  PyPSA-Eur coupling
***------------------------------------------------------------
sets
    tPy32(ttot)                 "Years coupled to PyPSA"
        /2025, 2030, 2035, 2040, 2045, 2050, 2055, 2060, 2070, 2080, 2090, 2100, 2110, 2130, 2150/

$ifthen "%c32_pypsa_multiregion%" == "on"
    regPy32(all_regi)           "Regions coupled to PyPSA"
        /DEU, FRA, EWN/

$elseif "%c32_pypsa_multiregion%" == "off"
    regPy32(all_regi)           "Regions coupled to PyPSA"
        /DEU/
$endif

    tePy32(all_te)              "Electricity technologies coupled to PyPSA"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, coalchp, tnrs, fnrs, ngt, windoff, dot, wind, hydro, spv/  !! TODO: What about CSP and geohdr?

    tePyDisp32(all_te)          "Dispatchable electricity technologies coupled to PyPSA (without grades)"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, coalchp, tnrs, fnrs, ngt, dot/

    tePyVRE32(all_te)           "Variable renewable electricity technologies coupled to PyPSA (with grades)"
        /windoff, wind, hydro, spv/

    entyPePy32(all_enty)        "Primary energy carriers for which prices are coupled to PyPSA"
        /peoil, pegas, pecoal, peur, pehyd, pewin, pesol, pebiolc/

    carrierPy32                 "Carrier from PyPSA"
        /"AC", "H2 demand REMIND"/
;

alias(regPy32,regPy32_2);

*** EOF ./modules/32_power/PyPSA/sets.gms
