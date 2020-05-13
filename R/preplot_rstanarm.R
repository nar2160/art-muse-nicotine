## setup ----

require(tidyverse)
require(magrittr)
require(rlang)

source(here::here("R", "paths.R"))
load(paste(stats_dir, "raw.rda", sep = "/"))
load(paste(stats_dir, "models_rstanarm.rda", sep = "/"))

posterior_preplot_params <- function (object) {
  out <- object %>%
    as.data.frame() %>%
    as_tibble() %>%
    mutate(iteration = 1:nrow(.)) %>%
    # removes all random effects and sigma terms. should yield fixed effects only
    select(-contains("["), -contains("sigma")) %>%
    rename(intercept = "(Intercept)") %>%
    pivot_longer(cols = -iteration, names_to = "term", values_to = "estimate")
  
  return (out)
}

posterior_preplot_bysubj <- function (object, newdata, pred_col = "y_pred", type = c("median", "mean", "by_iter", "trialwise"), draws = 1000) {
  # if (type == "trialwise" & draws > 10) stop("too many posterior_predict draws, probably!")
  if (type != "trialwise") {
    out <- object %>%
      rstanarm::posterior_linpred(transform = TRUE,
                                  newdata = newdata,
                                  re.form = NULL,
                                  draws = draws)
  } else {
    out <- object %>%
      rstanarm::posterior_predict(newdata = newdata,
                                  draws = draws,
                                  re.form = NULL)
  }
  if (type == "by_iter") {
    
    newdata %<>%
      # Must expand AFTER predictions is already done to repeat for iterations
      # need the "obs" column to make damn sure that the correct predicted points get pasted on the correct x values
      mutate(obs = 1:nrow(.),
             iteration = map(obs, ~1:draws)) %>%
      unchop(iteration)
    
    out %>%
      as_tibble() %>%
      mutate(iteration = 1:nrow(.)) %>%
      pivot_longer(cols = -iteration, names_to = "obs", values_to = pred_col) %>%
      mutate(obs = as.integer(obs)) %>%
      right_join(newdata, by = c("obs", "iteration")) %>%
      # the obs column obstructs any later pivoting, and is technically redundant if all the x cols are in there,
      # so get outta here
      select(-obs)
    
    return(out)
    
  } else if (type == "median" | type == "mean") {
    # Just the median of every predicted point for every subject
    # Note that this doesn't select in a paired way for the "median iteration"
    # returns a VECTOR which needs to get slapped onto newdata
    if (type == "median") {
      out %<>%
        apply(2, median)
    } else if (type == "mean") {
      out %<>%
        apply(2, mean)
    }
    out %<>%
      t() %>%
      c()
    
    newdata %<>%
      mutate(!!pred_col := out)
    
    return (newdata)
  } else if (type == "trialwise") {
    
    newdata %<>%
      # Must expand AFTER predictions is already done to repeat for iterations
      # need the "obs" column to make damn sure that the correct predicted points get pasted on the correct x values
      mutate(obs = 1:nrow(.))
    
    out %<>%
      t() %>%
      as_tibble(.name_repair = "universal") %>%
      mutate(obs = 1:nrow(.)) %>%
      right_join(newdata, by = "obs") %>%
      pivot_longer(cols = starts_with("..."), names_to = "iteration", values_to = pred_col) %>%
      mutate(iteration = as.integer(str_sub(iteration, start = 4L))) %>%
      # the obs column obstructs any later pivoting, and is technically redundant if all the x cols are in there,
      # so get outta here
      select(-obs)
    
    if (length(unique(out$iteration)) == 1) out %<>% select(-iteration)
    
    return(out)
    
  }
  
}

posterior_preplot_fixef <- function (object, newdata, pred_col = "y_pred", draws = 1000) {
  
  out <- object %>%
    rstanarm::posterior_linpred(transform = TRUE,
                                newdata = newdata,
                                re.form = NA,
                                draws = draws)
  
  newdata %<>%
    # Must expand AFTER predictions is already done to repeat for iterations
    # need the "obs" column to make damn sure that the correct predicted points get pasted on the correct x values
    mutate(obs = 1:nrow(.),
           iteration = map(obs, ~1:draws)) %>%
    unchop(iteration)
  
  out %<>%
    as_tibble() %>%
    mutate(iteration = 1:nrow(.)) %>%
    pivot_longer(cols = -iteration, names_to = "obs", values_to = pred_col) %>%
    mutate(obs = as.integer(obs)) %>%
    right_join(newdata, by = c("obs", "iteration")) %>%
    # the obs column obstructs any later pivoting, and is technically redundant if all the x cols are in there,
    # so get outta here
    select(-obs)
  
  return(out)
}

## preplots for A' model ----

preplots_params <- models %>%
  select(name, iterations = model) %>%
  mutate(iterations = map(iterations, ~posterior_preplot_params(.x)))

preplots_bysubj <- models %>%
  select(name, terms, data, model) %>%
  mutate(data = map2(data, terms, ~.x %>% select("subj_num", .y) %>% distinct()),
         predicted = map2(model, data, ~posterior_preplot_bysubj(.x, .y, pred_col = "resp_pred", type = "mean", draws = 400)),
         predicted = map_if(predicted, !startsWith(name, "dummy"),
                            ~.x %>%
                              mutate_at(vars(one_of("exptCond")), ~recode(.x, `-0.5` = "control", `0.5` = "relational")) %>%
                              mutate_at(vars(one_of("probe")), ~recode(.x, `-0.5` = "art", `0.5` = "room")) %>%
                              mutate(corResp = recode(corResp, `-0.5` = "fa", `0.5` = "hit"),
                                     on_smoking = recode(on_smoking, `-0.5` = "off", `0.5` = "on")),
                            .else = ~.x %>%
                              separate(trial_type,
                                       into = c("on_smoking", "exptCond", "probe")) %>%
                              mutate(corResp = recode(corResp, `-0.5` = "fa", `0.5` = "hit"),
                                     exptCond = recode(exptCond,
                                                       ctrl = "control",
                                                       rel = "relational"))),
         predicted = map(predicted, ~.x %>%
                           pivot_wider(names_from = corResp,
                                       values_from = resp_pred,
                                       names_prefix = "rate_") %>%
                           mutate(aprime = sdt_aprime(rate_hit, rate_fa)))) %>%
  select(name, predicted) %>%
  unnest(predicted) %>%
  mutate(deleteme = str_split(name, "_"),
         exptCond2 = map_chr(deleteme, ~if_else(length(.x) == 3, .x[2], .x[1])),
         exptCond2 = recode(exptCond2, rel = "relational", ctrl = "control"),
         probe2 = map_chr(deleteme, ~.x[length(.x)]),
         exptCond = coalesce(exptCond, exptCond2),
         probe = coalesce(probe, probe2),
         valid = coalesce(valid, 1L)) %>%
  select(-c(deleteme, exptCond2, probe2))

preplots_fixef <- models %>%
  select(name, terms, data, model) %>%
  mutate(data = map2(data, terms, ~.x %>% select(.y) %>% distinct()),
         predicted = map2(model, data, ~posterior_preplot_fixef(.x, .y, pred_col = "resp_pred")),
         predicted = map_if(predicted, !startsWith(name, "dummy"),
                            ~.x %>%
                              mutate_at(vars(one_of("exptCond")), ~recode(.x, `-0.5` = "control", `0.5` = "relational")) %>%
                              mutate_at(vars(one_of("probe")), ~recode(.x, `-0.5` = "art", `0.5` = "room")) %>%
                              mutate(corResp = recode(corResp, `-0.5` = "fa", `0.5` = "hit"),
                                     on_smoking = recode(on_smoking, `-0.5` = "off", `0.5` = "on")),
                            .else = ~.x %>%
                              separate(trial_type,
                                       into = c("on_smoking", "exptCond", "probe")) %>%
                              mutate(corResp = recode(corResp, `-0.5` = "fa", `0.5` = "hit"),
                                     exptCond = recode(exptCond,
                                                       ctrl = "control",
                                                       rel = "relational"))),
         predicted = map(predicted, ~.x %>%
                           pivot_wider(names_from = corResp,
                                       values_from = resp_pred,
                                       names_prefix = "rate_") %>%
                           mutate(aprime = sdt_aprime(rate_hit, rate_fa)))) %>%
  select(name, predicted) %>%
  unnest(predicted) %>%
  mutate(deleteme = str_split(name, "_"),
         exptCond2 = map_chr(deleteme, ~if_else(length(.x) == 3, .x[2], .x[1])),
         exptCond2 = recode(exptCond2, rel = "relational", ctrl = "control"),
         probe2 = map_chr(deleteme, ~.x[length(.x)]),
         exptCond = coalesce(exptCond, exptCond2),
         probe = coalesce(probe, probe2),
         valid = coalesce(valid, 1L)) %>%
  select(-c(deleteme, exptCond2, probe2))

preplots_raw_bysubj <- preplots_bysubj %>%
  filter(name != "manip_check") %>%
  mutate(name = recode(name,
                       full = "2x2x2",
                       dummy_art = "dummy_byprobe",
                       dummy_room = "dummy_byprobe"),
         name = if_else(startsWith(name, "sep"), "sep", name),
         name = paste0("model_", name)) %>%
  bind_rows(sdt_metrics %>%
              select(subj_num, on_smoking, exptCond, probe = cue, rate_fa, rate_hit, aprime) %>%
              mutate(name = "raw"))

preplots_raw_fixef <- preplots_fixef %>%
  filter(name != "manip_check") %>%
  mutate(name = recode(name,
                       dummy_art = "dummy_byprobe",
                       dummy_room = "dummy_byprobe"),
         name = if_else(startsWith(name, "sep"), "sep", name)) %>%
  arrange(name, iteration, probe, exptCond, on_smoking) %>%
  group_by(name, iteration, probe, exptCond) %>%
  summarize(diff_rate_fa = diff(rate_fa),
            diff_rate_hit = diff(rate_hit),
            diff_aprime = diff(aprime)) %>%
  pivot_longer(starts_with("diff"), names_to = "metric_type", values_to = "diff_smoking", names_prefix = "diff_") %>%
  nest(diffs = -c(name, probe, exptCond, metric_type)) %>%
  mutate(diff_smoking_q025 = map_dbl(diffs, ~quantile(.x$diff_smoking, .025)),
         diff_smoking_q50 = map_dbl(diffs, ~median(.x$diff_smoking)),
         diff_smoking_q975 = map_dbl(diffs, ~quantile(.x$diff_smoking, .975))) %>%
  left_join(sdt_metrics %>%
              rename(probe = cue) %>%
              arrange(subj_num, probe, exptCond, on_smoking) %>%
              group_by(subj_num, probe, exptCond) %>%
              summarize(diff_rate_fa = diff(rate_fa),
                        diff_rate_hit = diff(rate_hit),
                        diff_aprime = diff(aprime)) %>%
              ungroup() %>%
              pivot_longer(starts_with("diff"), names_to = "metric_type", values_to = "diff_smoking", names_prefix = "diff_") %>%
              group_by(probe, exptCond, metric_type) %>%
              summarize(raw_median_diff_smoking = median(diff_smoking),
                        raw_mean_diff_smoking = mean(diff_smoking)),
            by = c("probe", "exptCond", "metric_type"))

save(preplots_params, preplots_bysubj, preplots_fixef, preplots_raw_bysubj, preplots_raw_fixef, file = paste(stats_dir, "preplots_rstanarm.rda", sep = "/"))

## preplots for RT model ----

preplots_rt_params <- models %>%
  select(name, iterations = model_rt) %>%
  mutate(iterations = map(iterations, ~posterior_preplot_params(.x)))

preplots_rt_fixef <- models %>%
  select(name, terms_rt, data, model_rt) %>%
  rename(terms = terms_rt, model = model_rt) %>%
  mutate(data = map2(data, terms, ~.x %>% select(.y) %>% distinct()),
         predicted = map2(model, data, ~posterior_preplot_fixef(.x, .y, pred_col = "log_rt_pred")),   
         predicted = map_if(predicted, !startsWith(name, "dummy"),
                            ~.x %>%
                              mutate_at(vars(one_of("exptCond")), ~recode(.x, `-0.5` = "control", `0.5` = "relational")) %>%
                              mutate_at(vars(one_of("probe")), ~recode(.x, `-0.5` = "art", `0.5` = "room")) %>%
                              mutate(resp = recode(resp_c, `-0.5` = "no_match", `0.5` = "match"),
                                     corResp = recode(corResp, `-0.5` = "no_match", `0.5` = "match"),
                                     on_smoking = recode(on_smoking, `-0.5` = "off", `0.5` = "on")),
                            .else = ~.x %>%
                              separate(trial_type,
                                       into = c("on_smoking", "exptCond", "probe")) %>%
                              mutate(resp = recode(resp_c, `-0.5` = "no_match", `0.5` = "match"),
                                     corResp = recode(corResp, `-0.5` = "fa", `0.5` = "hit"),
                                     exptCond = recode(exptCond,
                                                       ctrl = "control",
                                                       rel = "relational")))) %>%
  select(name, predicted) %>%
  unnest(predicted) %>%
  mutate(deleteme = str_split(name, "_"),
         exptCond2 = map_chr(deleteme, ~if_else(length(.x) == 3, .x[2], .x[1])),
         exptCond2 = recode(exptCond2, rel = "relational", ctrl = "control"),
         probe2 = map_chr(deleteme, ~.x[length(.x)]),
         exptCond = coalesce(exptCond, exptCond2),
         probe = coalesce(probe, probe2),
         valid = coalesce(valid, 1L),
         acc = case_when(resp == "match" & corResp == "match" ~ "hit",
                         resp == "no_match" & corResp == "match" ~ "miss",
                         resp == "match" & corResp == "no_match" ~ "fa",
                         resp == "no_match" & corResp == "no_match" ~ "cr",
                         TRUE ~ NA_character_),
         rt_pred = exp(log_rt_pred)) %>%
  select(-c(deleteme, exptCond2, probe2, resp_c))

save(preplots_rt_params, preplots_rt_fixef, file = paste(stats_dir, "preplots_rt_rstanarm.rda", sep = "/"))

