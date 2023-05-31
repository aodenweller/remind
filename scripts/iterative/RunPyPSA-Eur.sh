scenario="$(basename "$(pwd)")"
cd /p/tmp/adrianod/pypsa-eur
source /home/jhampp/software/micromamba_1.4.2/etc/profile.d/micromamba.sh
micromamba run --name pypsa-eur snakemake -call --profile cluster_config -s Snakefile_remind --config remind_scenario=${scenario} -- results/${scenario}/coupling-parameters/i1/coupling-parameters.gdx