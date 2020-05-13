stats_dir = ignore/data_R
data_dir = materials/data

$(stats_dir)/boots.rda $(stats_dir)/aprime_by_ppm.rda: \
	R/model_boot.R \
	R/paths.R \
	$(stats_dir)/raw.rda
	Rscript -e 'source("$<")'

$(stats_dir)/preplots_rstanarm.rda $(stats_dir)/preplots_rt_rstanarm.rda: \
	R/preplot_rstanarm.R \
	R/paths.R \
	$(stats_dir)/models_rstanarm.rda \
	$(stats_dir)/raw.rda
	Rscript -e 'source("$<")'

$(stats_dir)/models_rstanarm.rda: \
	R/model_rstanarm.R \
	R/paths.R \
	$(stats_dir)/raw.rda
	Rscript -e 'source("$<")'
	
$(stats_dir)/raw.rda: \
	R/preprocess.R \
	R/paths.R \
	$(shell find $(data_dir)/*.txt -type f) \
	$(data_dir)/demo_smoke_habits.csv
	Rscript -e 'source("$<")'
	