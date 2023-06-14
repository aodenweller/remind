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

    tPy32s(ttot)                "Years coupled to PyPSA for which the discount rate p32_PyDisrate can be calculated"
        /2025, 2030, 2035, 2040, 2045, 2050, 2055, 2060, 2070, 2080, 2090, 2100, 2110, 2130/

    regPy32(all_regi)           "Regions coupled to PyPSA"
        /DEU/

    tePy32(all_te)              "REMIND secondary energy electricity technologies coupled to PyPSA"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, pcc, pco, coalchp, tnrs, fnrs, ngt, windoff, dot, wind, hydro, spv/  !! TODO: What about CSP and geohdr?

    tePy32disp(tePy32)          "REMIND dispatchable secondary energy electricity technologies (no grades)"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, pcc, pco, coalchp, tnrs, fnrs, ngt, dot/

    tePy32nondisp(tePy32)       "REMIND non-dispatchable secondary energy electricity technologies (with grades)"
        /windoff, wind, spv/
;

***------------------------------------------------------------
***                  PyPSA-Eur mappings
***------------------------------------------------------------

*** Most mappings have been shifted to  the PyPSA snakemake workflow


*** EOF ./modules/32_power/PyPSA/sets.gms
