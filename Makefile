
ignore/data_R/boots.rda ignore/data_R/aprime_by_ppm.rda: model_boot.R ignore/data_R/raw.rda
	Rscript -e 'source("$<")'

ignore/data_R/preplots_rstanarm.rda ignore/data_R/preplots_rt_rstanarm.rda: preplot_rstanarm.R ignore/data_R/models_rstanarm.rda ignore/data_R/raw.rda
	Rscript -e 'source("$<")'

ignore/data_R/models_rstanarm.rda: model_rstanarm.R ignore/data_R/raw.rda
	Rscript -e 'source("$<")'
	
ignore/data_R/raw.rda: preprocess.R $(shell find ignore/data_raw/raw/*.txt -type f)
	Rscript -e 'source("$<")'
	