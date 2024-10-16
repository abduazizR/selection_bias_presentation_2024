# About
## This is code to simulate the wasabi example from Hernan's book Causal inference what if to demonstrate selection bias and censoring (section 8.4)


pacman::p_load(
  tidyverse,
  simcausal,
  broom,
  arrow,
  modelr,
  rstatix,
  WeightIt
)

wasabi <- expand_grid(
  L = c(0, 1),
  A = c(0, 1),
  C = 0:1,
  Y = 0:1
) %>%
  mutate(n = case_when(
    L == 0 & A == 0 & C == 0 & Y == 0 ~ 8,
    L == 0 & A == 0 & C == 0 & Y == 1 ~ 2,
    L == 0 & A == 0 & C == 1 & Y == 0 ~ 0,
    L == 0 & A == 0 & C == 1 & Y == 1 ~ 0,
    L == 0 & A == 1 & C == 0 & Y == 0 ~ 4,
    L == 0 & A == 1 & C == 0 & Y == 1 ~ 1,
    L == 0 & A == 1 & C == 1 & Y == 0 ~ 4,
    L == 0 & A == 1 & C == 1 & Y == 1 ~ 1,
    L == 1 & A == 0 & C == 0 & Y == 0 ~ 3,
    L == 1 & A == 0 & C == 0 & Y == 1 ~ 9,
    L == 1 & A == 0 & C == 1 & Y == 0 ~ 2,
    L == 1 & A == 0 & C == 1 & Y == 1 ~ 6,
    L == 1 & A == 1 & C == 0 & Y == 0 ~ 1,
    L == 1 & A == 1 & C == 0 & Y == 1 ~ 3,
    L == 1 & A == 1 & C == 1 & Y == 0 ~ 4,
    L == 1 & A == 1 & C == 1 & Y == 1 ~ 12
  )) |>
  uncount(n)


# No adjustment for censoring --------------------------------------------
wasabi_w |>
  filter(C == 0) |>
  group_by(A) |>
  summarise(
    outcome = mean(Y)
  ) |>
  pivot_wider(names_from = A, values_from = outcome) |>
  mutate(RR = `1` / `0`)



# Adjustment for censoring by weighting ----------------------------------
wasabi |>
  group_by(L, A) |>
  mutate(p_uncens = 1 - mean(C)) |>
  mutate(w = 1 / p_uncens) |>
  ungroup() |>
  filter(C == 0) |>
  group_by(A) |>
  summarise(
    w_outcome = weighted.mean(Y, w),
  ) |>
  pivot_wider(names_from = A, values_from = w_outcome) |>
  mutate(RR = `1` / `0`)


# Investigate weights
wasabi |>
  group_by(L, A) |>
  mutate(p_uncens = 1 - mean(C)) |>
  mutate(w = 1 / p_uncens) |>
  ungroup() |>
  get_summary_stats(w)
