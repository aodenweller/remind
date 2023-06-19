*** |  (C) 2006-2022 Potsdam Institute for Climate Impact Research (PIK)
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
$ontext
if ((iteration.val gt c32_startIter_PyPSA),
  Execute "Rscript -e 'library(gdx); library(remindPypsa); remindPypsa::createValidation();'";
);
$offtext

$ontext
!! Test call PyPSA-Eur
!! Temporarily store and then set numeric round format and number of decimals
sm_tmp  = logfile.nr;
sm_tmp2 = logfile.nd;
logfile.nr = 1;
logfile.nd = 0;

!! Command line arguments: (i) PyPSA directory and (ii) current iteration
Put_utility logfile, "Exec" /
  "./RunPyPSA-Eur.sh %c32_pypsa_dir% " iteration.val:0:0;

!! Reset round format and number of decimals
logfile.nr = sm_tmp;
logfile.nd = sm_tmp2;
$offtext

*** EOF ./modules/32_power/PyPSA/presolve.gms
