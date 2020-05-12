ignore/data_R/boots.rda ignore/data_R/aprime_by_ppm.rda: R/model_boot.R ignore/data_R/raw.rda
	Rscript -e 'source("$<")'

ignore/data_R/preplots_rstanarm.rda ignore/data_R/preplots_rt_rstanarm.rda: R/preplot_rstanarm.R ignore/data_R/models_rstanarm.rda ignore/data_R/raw.rda
	Rscript -e 'source("$<")'

ignore/data_R/models_rstanarm.rda: R/model_rstanarm.R ignore/data_R/raw.rda
	Rscript -e 'source("$<")'
	
ignore/data_R/raw.rda: R/preprocess.R $(shell find ignore/materials/data/*.txt -type f)
	Rscript -e 'source("$<")'
	