*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/sets.gms

***------------------------------------------------------------
***                  PyPSA-Eur coupling
***------------------------------------------------------------

*** REMIND sets used for the PyPSA coupling
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

    tePy32(all_te)              "Electricity generation technologies coupled to PyPSA"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, coalchp, tnrs, fnrs, ngt, windoff, dot, windon, hydro, spv/  !! TODO: What about CSP and geohdr?

    teStoreTransPy32(all_te)    "Storage and transmission technologies coupled to PyPSA"
        /elh2, h2turb/

    tePyDisp32(all_te)          "Dispatchable electricity technologies coupled to PyPSA (without grades), used for peak residual load"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, coalchp, tnrs, fnrs, ngt, dot/

    tePyVRE32(all_te)           "Variable renewable electricity technologies coupled to PyPSA (with grades), used for potentials if applicable"
        /windoff, windon, hydro, spv/

    entyPePy32(all_enty)        "Primary energy carriers for which prices are coupled to PyPSA"
        /peoil, pegas, pecoal, peur, pehyd, pewin, pesol, pebiolc/ !! TODO: Remove pehyd, pewin, pesol
;

*** Sets to import PyPSA data
sets
    carrierPy32                 "Energy carrier from PyPSA"
        /"AC", "H2 demand REMIND"/

    storeTransPy32              "Storage and transmission technologies from PyPSA"
        /"AC", "DC", "H2", "H2 fuel cell", "H2 electrolysis", "battery", "battery charger", "battery discharger"/
;

alias(regPy32,regPy32_2);

*** EOF ./modules/32_power/PyPSA/sets.gms
