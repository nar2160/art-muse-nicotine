## setup ----

require(tidyverse)
require(magrittr)

load(here::here("ignore", "data_R", "raw.rda"))

## resample the bootstrap iterations ----

boots_by_subj <- raw %>%
  filter(valid == 1) %>%
  select(-c(valid, session_num, condition, cue)) %>%
  mutate(corResp = recode(corResp, `0` = "fa", `1` = "hit"),
         on_smoking = recode(on_smoking, `0` = "off", `1` = "on"),
         exptCond = recode(exptCond, `0` = "control", `1` = "relational")) %>%
  nest(trials = -c(subj_num, ppm, on_smoking, exptCond, probe, corResp)) %>%
  nest(conditions = -subj_num) %>%
  nest(subjects = everything()) %>%
  # note that here, 1:n() is 1:1
  slice(rep(1:n(), each = 200)) %>%
  mutate(iteration = 1:n(),
         # resample outer level: subjects
         subjects = furrr::future_map(subjects, ~sample_frac(.x, size = 1, replace = TRUE) %>%
                                        mutate(subj_num = 1:nrow(.)),
                                      .progress = TRUE)) %>%
  unnest(subjects) %>%
  unnest(conditions) %>%
  # CHANGE N BOOTSTRAPS HERE
  # resample inner level: trials (honoring condition structure)
  mutate(boots = furrr::future_map(trials, ~rsample::bootstraps(.x, times = 1) %>%
                                     mutate(rate = map_dbl(splits, ~mean(as.data.frame(.x)$resp))) %>% 
                                     select(rate),
                                   .progress = TRUE)) %>%
  select(-trials) %>%
  unnest(boots) %>%
  pivot_wider(names_from = corResp, values_from = rate, names_prefix = "rate_") %>%
  mutate(aprime = sdt_aprime(rate_hit, rate_fa),
         aprime = coalesce(aprime, 0.5)) %>%
  nest(data = -iteration)

boots_by_trial <- raw %>%
  filter(valid == 1) %>%
  select(-c(valid, session_num, condition, cue)) %>%
  mutate(corResp = recode(corResp, `0` = "fa", `1` = "hit"),
         on_smoking = recode(on_smoking, `0` = "off", `1` = "on"),
         exptCond = recode(exptCond, `0` = "control", `1` = "relational")) %>%
  nest(trials = -c(subj_num, on_smoking, exptCond, probe, corResp)) %>%
  # CHANGE N BOOTSTRAPS HERE
  # resample inner level: trials (honoring condition structure)
  mutate(boots = furrr::future_map(trials, ~rsample::bootstraps(.x, times = 100) %>%
                                     mutate(iteration = 1:nrow(.),
                                            rate = map_dbl(splits, ~mean(as.data.frame(.x)$resp))) %>% 
                                     select(iteration, rate),
                                   .progress = TRUE)) %>%
  select(-trials) %>%
  unnest(boots) %>%
  pivot_wider(names_from = corResp, values_from = rate, names_prefix = "rate_") %>%
  mutate(aprime = sdt_aprime(rate_hit, rate_fa),
         # if both hit and FA rates are 0 or 1, it NaNs out, but imputing 0.5
         # makes sense here since they should technically be at chance
         aprime = coalesce(aprime, 0.5)) %>%
  group_by(subj_num, on_smoking, exptCond, probe) %>%
  summarize_at(c("rate_hit", "rate_fa", "aprime"),
               list(q05 = ~quantile(., .05),
                    q25 = ~quantile(., .25),
                    q50 = ~median(.),
                    q75 = ~quantile(., .75),
                    q95 = ~quantile(., .95))) %>%
  pivot_longer(cols = contains("_q"), names_to = c("metric_type", ".value"),
               names_pattern = "(.*)_(...)")

## make aprime_by_ppm (regression on the RAW data) ----

aprime_by_ppm <- raw %>%
  filter(valid == 1) %>%
  mutate(corResp = recode(corResp, `0` = "fa", `1` = "hit"),
         on_smoking = recode(on_smoking, `0` = "off", `1` = "on"),
         exptCond = recode(exptCond, `0` = "control", `1` = "relational")) %>%
  group_by(subj_num, ppm, on_smoking, exptCond, probe, corResp) %>%
  summarize(rate = mean(resp)) %>%
  pivot_wider(names_from = corResp, values_from = rate, names_prefix = "rate_") %>%
  mutate(aprime = sdt_aprime(rate_hit, rate_fa)) %>%
  select(-starts_with("rate")) %>%
  pivot_wider(names_from = on_smoking, values_from = c(aprime, ppm)) %>%
  mutate(ppm_diff = ppm_on - ppm_off,
         aprime_diff = aprime_on - aprime_off,
         aprime_off_c = aprime_off - 0.5) %>%
  arrange(exptCond, probe, aprime_off, aprime_diff) %>%
  group_by(exptCond, probe) %>%
  mutate(rank_aprime_off = 1:n()) %>%
  nest(data = -c(exptCond, probe)) %>%
  mutate(resid_aprime_diff = map(data, ~lm(aprime_diff ~ aprime_off_c, data = .x) %>%
                                   broom::augment() %>%
                                   select(aprime_diff_resid = .resid)),
         resid_ppm_diff = map(data, ~lm(ppm_diff ~ aprime_off_c, data = .x) %>%
                                broom::augment() %>%
                                select(ppm_diff_resid = .resid)),
         data = pmap(list(data, resid_aprime_diff, resid_ppm_diff),
                     function(a, b, c) {bind_cols(a, b, c)}),
         model = map(data, ~lm(aprime_diff ~ aprime_off_c + ppm_diff, data = .x)),
         augs = map(model, ~.x %>%
                      broom::augment() %>%
                      select(aprime_diff_fit = .fitted)),
         resid_augs = map(data, ~lm(aprime_diff_resid ~ ppm_diff_resid, data = .x) %>%
                            broom::augment() %>%
                            select(aprime_diff_fit_resid = .fitted)),
         data = map2(data, augs, ~bind_cols(.x, .y)),
         data = map2(data, resid_augs, ~bind_cols(.x, .y))) %>%
  select(-starts_with("resid"), -augs)

## make aprime_by_ppm_boot ----

aprime_by_ppm_boot <- boots_by_subj %>%
  unnest(data) %>%
  select(-starts_with("rate")) %>%
  pivot_wider(names_from = on_smoking, values_from = c(aprime, ppm)) %>%
  mutate(ppm_diff = ppm_on - ppm_off,
         aprime_diff = aprime_on - aprime_off,
         aprime_off_c = aprime_off - 0.5) %>%
  nest(data = -c(iteration, exptCond, probe)) %>%
  mutate(resid_aprime_diff = map(data, ~lm(aprime_diff ~ aprime_off_c, data = .x) %>% broom::augment() %>% select(aprime_diff_resid = .resid)),
         resid_ppm_diff = map(data, ~lm(ppm_diff ~ aprime_off_c, data = .x) %>% broom::augment() %>% select(ppm_diff_resid = .resid)),
         data = pmap(list(data, resid_aprime_diff, resid_ppm_diff), function(a, b, c) {bind_cols(a, b, c)}),
         model = map(data, ~lm(aprime_diff ~ aprime_off_c + ppm_diff, data = .x)),
         model_resid = map(data, ~lm(aprime_diff_resid ~ ppm_diff_resid, data = .x)),
         coefs = map(data, ~lm(aprime_diff ~ aprime_off_c + ppm_diff, data = .x) %>%
                       broom::tidy()),
         coefs_unadj = map(data, ~lm(aprime_diff ~ ppm_diff, data = .x) %>%
                             broom::tidy())) %>%
  left_join(aprime_by_ppm %>%
              select(exptCond, probe, data_raw = data, coefs_raw = model) %>%
              mutate(coefs_raw = map(coefs_raw,
                                     ~broom::tidy(.) %>%
                                       rename_if(is.numeric, ~paste0(., "_raw")))),
            by = c("exptCond", "probe")) %>%
  mutate(predicted_resid = map2(data_raw, model_resid,
                                ~.x %>%
                                  select(ppm_diff_resid) %>%
                                  predict(.y, newdata = .)),
         data_raw = map2(data_raw, predicted_resid,
                         ~.x %>%
                           mutate(obs = 1:nrow(.), predicted = .y))) %>%
  select(-ends_with("resid"), -data)

## finish up ----

save(boots_by_subj, boots_by_trial, file = here::here("ignore", "data_R", "boots.rda"))

save(aprime_by_ppm, aprime_by_ppm_boot, file = here::here("ignore", "data_R", "aprime_by_ppm.rda"))
