*** |  (C) 2006-2022 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/32_power/PyPSA/sets.gms

***------------------------------------------------------------
***                  Sets for PyPSA
***------------------------------------------------------------
sets
    tPy32(ttot)                 "Years coupled to PyPSA"
        /2025, 2030, 2035, 2040, 2045, 2050, 2055, 2060, 2070, 2080, 2090, 2100, 2110, 2130, 2150/

    regPy32(all_regi)           "Regions coupled to PyPSA"
        /DEU/

    tePyImp32                   "Technology names as imported from PyPSA"
        /all_coal, all_offwind, biomass, CCGT, nuclear, OCGT, oil, onwind, ror, solar/

    tePy32(all_te)              "REMIND secondary energy electricity technologies coupled to PyPSA"
        /biochp, bioigcc, bioigccc, ngcc, ngccc, gaschp, igcc, igccc, pc, pcc, pco, coalchp, tnrs, fnrs, ngt, windoff, dot, wind, hydro, spv/  !! TODO: What about CSP and geohdr?

    varPyImp32                  "Variable names as imported from PyPSA"
        /capfac/
;

***------------------------------------------------------------
***                  Mappings for PyPSA
***------------------------------------------------------------
sets
    tePyMap32(tePyImp32,tePy32) "Technology mapping of PyPSA and REMIND"
        /
        all_coal.gaschp
        all_coal.igcc
        all_coal.igccc
        all_coal.pc
        all_coal.pcc
        all_coal.pco
        all_coal.coalchp
        all_offwind.windoff
        biomass.biochp
        biomass.bioigcc
        biomass.bioigccc
        CCGT.ngcc
        CCGT.ngccc
        nuclear.tnrs
        nuclear.fnrs
        OCGT.ngt
        oil.dot
        onwind.wind
        ror.hydro
        solar.spv
        /
    
    tePyMapDisp32(tePyImp32,tePy32) "Technology mapping of PyPSA and REMIND for dispatchable technologies only"
        /
        all_coal.gaschp
        all_coal.igcc
        all_coal.igccc
        all_coal.pc
        all_coal.pcc
        all_coal.pco
        all_coal.coalchp
        biomass.biochp
        biomass.bioigcc
        biomass.bioigccc
        CCGT.ngcc
        CCGT.ngccc
        nuclear.tnrs
        nuclear.fnrs
        OCGT.ngt
        oil.dot
        ror.hydro
        /
;


*** EOF ./modules/32_power/PyPSA/sets.gms
