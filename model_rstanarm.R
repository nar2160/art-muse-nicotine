## setup ----

require(tidyverse)
require(magrittr)
require(rlang)
options(mc.cores = parallel::detectCores())

load(here::here("ignore", "data_R", "raw.rda"))

## fit giant rstanarm models ----

models <- tibble(has_probe = c(rep(list(c("art", "room")), 3),
                               as.list(rep(c("art", "room"),
                                           times = 3))),
                 has_exptCond = c(rep(list(0:1), 3 + 2), as.list(rep(0:1, each = 2))),
                 has_valid = c(list(1L, 0:1),
                               as.list(rep(1L, 1 + 2 + 4))),
                 name = c("full", "manip_check", "dummy_all",
                          rep("dummy", 2),
                          rep("sep", 4))) %>%
  mutate(name = if_else(lengths(has_exptCond) == 1,
                        map2_chr(name, has_exptCond, ~.y %>%
                                   recode(`0` = "ctrl",
                                          `1` = "rel") %>%
                                   paste(.x, ., sep = "_", collapse = "_")),
                        name),
         name = if_else(lengths(has_probe) == 1,
                        map2_chr(name, has_probe, ~paste(.x, .y, sep = "_", collapse = "_")),
                        name),
         terms = case_when(name == "full" ~ list(c("corResp", "probe", "on_smoking", "exptCond")),
                           name == "manip_check" ~ list(c("corResp", "valid", "probe", "on_smoking", "exptCond")),
                           startsWith(name, "dummy") ~ list(c("corResp", "trial_type")),
                           startsWith(name, "sep") ~ list(c("corResp", "on_smoking")),
                           TRUE ~ list(NA)),
         ranefs = case_when(name == "full" ~ "(1 + (corResp + probe + exptCond + on_smoking)^2 | subj_num)",
                            name == "manip_check" ~ "(1 + corResp + valid + probe + exptCond + on_smoking | subj_num)",
                            startsWith(name, "dummy") ~ "(1 + corResp * trial_type | subj_num)",
                            startsWith(name, "sep") ~ "(1 + corResp * on_smoking | subj_num)",
                            TRUE ~ NA_character_),
         data = map(has_valid, ~raw %>% filter(valid %in% .x)),
         data = map2(data, has_probe, ~.x %>% filter(probe %in% .y)),
         data = map2(data, has_exptCond, ~.x %>% filter(exptCond %in% .y)),
         data = map(data, ~.x %>%
                      # EFFECT CODE TO THE HEAVENS!!!
                      mutate(
                        trial_type = case_when(
                          on_smoking == 0 & exptCond == 0 ~ "off_ctrl",
                          on_smoking == 0 & exptCond == 1 ~ "off_rel",
                          on_smoking == 1 & exptCond == 0 ~ "on_ctrl",
                          on_smoking == 1 & exptCond == 1 ~ "on_rel",
                          TRUE ~ NA_character_
                        ),
                        trial_type = paste(trial_type, probe, sep = "_"),
                        trial_type = fct_rev(trial_type),
                        resp_c = resp - 0.5,
                        corResp = corResp - 0.5,
                        exptCond = exptCond - 0.5,
                        probe = recode(probe,
                                       art = -0.5,
                                       room = 0.5),
                        on_smoking = on_smoking - 0.5,
                        log_rt = log(rt * 1000))),
         txt_formula = map_chr(terms, ~paste(.x, collapse = " + ")),
         txt_formula = case_when(
           name == "full" ~ paste0("(", txt_formula, ")^3"),
           name == "manip_check" ~ paste0("(", txt_formula, ")^3"),
           startsWith(name, "dummy") | startsWith(name, "sep") ~ paste0("(", txt_formula, ")^2")),
         txt_formula = paste("resp ~", txt_formula, "+", ranefs),
         # all the RT model setting stuff is here now
         terms_rt = map(terms, ~c("resp_c", .x)),
         txt_formula_rt = map_chr(terms_rt, ~paste(.x, collapse = " + ")),
         ranefs_rt = case_when(
           name == "full" ~ paste0("(1 + (", txt_formula_rt,")^3 | subj_num)"),
           name == "manip_check" ~ paste0("(1 + ", txt_formula_rt," | subj_num)"),
           startsWith(name, "dummy") | startsWith(name, "sep") ~ paste0("(1 + (", txt_formula_rt,")^2 | subj_num)"),
           TRUE ~ NA_character_
         ),
         txt_formula_rt = map_chr(terms_rt, ~paste(.x, collapse = " + ")),
         txt_formula_rt = case_when(
           name == "full" ~ paste0("(", txt_formula_rt, ")^3"),
           name == "manip_check" ~ paste0("(", txt_formula_rt, ")^3"),
           startsWith(name, "dummy") | startsWith(name, "sep") ~ paste0("(", txt_formula_rt, ")^3")),
         txt_formula_rt = paste("log_rt ~", txt_formula_rt, "+", ranefs_rt),
         # special estimation settings for some of the models
         init_r. = 1,
         iter. = if_else(startsWith(name, "sep"), 3000L, 2000L))

models %<>%
  mutate(model = pmap(list(txt_formula, data, init_r., iter.), 
                      function(a, b, c, d) {
                        rstanarm::stan_glmer(as.formula(a),
                                             family = binomial(link = "logit"),
                                             data = b,
                                             prior = rstanarm::cauchy(0, 2.5),
                                             prior_intercept = rstanarm::cauchy(0, 2.5),
                                             init_r = c,
                                             iter = d)
                      }))

models %<>%
  mutate(model_rt = pmap(list(txt_formula_rt, data, init_r., iter.), 
                         function(a, b, c, d) {
                           rstanarm::stan_glmer(as.formula(a),
                                                family = gaussian,
                                                data = b,
                                                prior = rstanarm::normal(0, 2.5),
                                                prior_intercept = rstanarm::normal(0, 10),
                                                init_r = c,
                                                iter = d)
                         }))


save(models, file = here::here("ignore", "data_R", "models_rstanarm.rda"))
