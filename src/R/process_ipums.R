cat('\014')

#############
### Setup ###
#############

suppressPackageStartupMessages({
  library(dplyr)
  library(ipumsr)
  library(readxl)
})


##############
### Import ###
##############

ipums_ddi = ipumsr::read_ipums_ddi('./data/base/usa_00007.xml')

acs_2015_2017 = ipumsr::read_ipums_micro(ddi = './data/base/usa_00007.xml')

# Get notes for certain variables.
val_labels = acs_2015_2017 %>%
  select_if(is.labelled) %>%
  lapply(FUN = ipumsr::ipums_val_labels)

# Get rid of labels in data. They mess with dplyr verbs.
acs_2015_2017 = acs_2015_2017 %>%
  mutate_if(.predicate = is.labelled,
            .funs = as.character) %>%
  # Convert numeric variables.
  mutate_at(.vars = vars(AGE, UHRSWORK:INCTOT_POP2),
            .funs = as.numeric)

# Load list of names of all majors and categories, & their FOD1P codes.
# From Ben Casselman: https://github.com/fivethirtyeight/data/blob/master/college-majors/majors-list.csv
# Major categories come from Carnevale et al (2011).
# https://cew.georgetown.edu/cew-reports/whats-it-worth-the-economic-value-of-college-majors/
# https://docs.google.com/viewer?url=https%3A%2F%2F1gyhoq479ufd3yna29x7ubjn-wpengine.netdna-ssl.com%2Fwp-content%2Fuploads%2F2014%2F11%2Fwhatsitworth-complete.pdf&pdf=true
majors = read.csv('./data/base/majors.csv') %>%
  mutate(FOD1P = as.character(FOD1P),
         major = stringr::str_to_title(major))

# Load list of low-wage occupations.
# From Ben Casselman: https://github.com/fivethirtyeight/data/blob/master/college-majors/college-majors-rscript.R
# Lines 62-86.
low_end = read.csv('./data/base/low_end.csv') %>%
  mutate(code = as.character(code))

# Load list of jobs that don't require a college degree.
# As defined by Abel et al (2014): https://goo.gl/mJZuQ7
# This data is non-public, so it won't be in the below path.
noncollege = readxl::read_excel(path = './data/base/Everet Rummel_Data Request_Occupation Codes_01-03-2018.xlsx',
                                sheet = 'OCC') %>%
  filter(College == 0) %>%
  mutate(OCC = as.character(OCC))


#################
### Transform ###
#################

# Create variables.
my_acs = acs_2015_2017 %>%
  # Add primary major. Maybe look at secondary majors later.
  left_join(majors,
            by = c('DEGFIELDD' = 'FOD1P')) %>%
  mutate(
    # Has a "low-end" job.
    low_end = if_else(OCC %in% low_end$code, 1, 0),
    # Has a job that doesn't typically require a college degree.
    noncollege = if_else(OCC %in% noncollege$OCC, 1, 0),
    # Works full-time, year-round.
    ftyr = if_else(WKSWORK2 == '6'
                   & UHRSWORK >= 35,
                   1, 0)
  ) %>%
  # Adjust income variables for inflation (2017 $).
  # See: https://usa.ipums.org/usa/acsincadj.shtml
  mutate_at(
    .vars = vars(INCTOT:INCTOT_POP2),
    .funs = funs(
      if_else(YEAR != 2017,
              . * 1.011189,
              .)
    )
  )


#############
### Check ###
#############

# Unique persons
length(unique(my_acs$SERIAL))
# 1,049,506

# No major info.
sum(is.na(my_acs$DEGFIELD))
# [1] 0

# Employed but no reported usual hours.
sum(my_acs$EMPSTAT == '0'
    & my_acs$UHRSWORK == 0)
# [1] 0

# No employment info.
sum(my_acs$EMPSTAT == '0')
# [1] 0

sum(my_acs$EMPSTATD == '0')
# [1] 0

# Less than a bachelor's.
sum(!my_acs$EDUCD %in% c('101', '114', '115', '116'))
# [1] 0

# Not considered a "recent" grad.
sum(my_acs$AGE > 27)                   # Filter out.   x
# 2,022,016

# Following Rickman et al (2015), I remove those claiming to work ftyr,
# but w/ reported nominal earnings lower than what is legally possible.
# $12,687 ($7.25 * 35 * 50, rounded down)
# https://docs.google.com/viewer?url=http%3A%2F%2Fftp.iza.org%2Fdp8984.pdf&pdf=true
sum(my_acs$ftyr == 1
    & my_acs$INCEARN < 12687)           # Filter out.   x
# [1] 158,648


##############
### Filter ###
##############

# Universe: "Recent college grads"
#  - Age 22-27, inclusive
#  - At least a bachelor's degree
#  - Info on college major reported
#  - Extra: Reported earnings above "legal threshold" of income
recent_grads = my_acs %>%
  filter(AGE < 28
         & !(ftyr == 1 & INCEARN < 12687))

# Additionally, we want a dataset of recent grads who are employed FTYR only.
recent_grads_ftyr = recent_grads %>%
  filter(ftyr == 1)


#################
### Aggregate ###
#################

TOT_RECENT_GRADS = nrow(recent_grads)
# [1] 203,991

WGT_TOT_RECENT_GRADS = sum(recent_grads$PERWT)
# [1] 23,287,245

TOT_RECENT_GRADS_FTYR = nrow(recent_grads_ftyr)
# [1] 106,309

WGT_TOT_RECENT_GRADS_FTYR = sum(recent_grads_ftyr$PERWT)
# [1] 12,260,601

WGT_TOT_RECENT_GRADS_FTYR / WGT_TOT_RECENT_GRADS
# [1] 0.5264943

# Create major-level dataset summarizing data for all recent college grads,
# regardless of employment status.
MAJ_recent_grads = recent_grads %>%
  group_by(major_category, major) %>%
  summarize(
    unwgt_num = n(),
    num = sum(PERWT),

    # Edu info
    num_grad = sum(PERWT[GRADEATTD == '70']), # Includes working grad students.
    num_went_grad = sum(PERWT[EDUCD %in% c('114', '115', '116')
                              & SCHOOL == '1']),
    num_no_grad = sum(PERWT[!EDUCD %in% c('114', '115', '116')
                            & SCHOOL == '1']),
    pct = num / WGT_TOT_RECENT_GRADS,
    pct_grad = num_grad / num,
    pct_went_grad = num_went_grad / num,
    pct_no_grad = num_no_grad / num,

    # Labor market info
    num_lab_force = sum(PERWT[LABFORCE == '2']),
    num_nilf = sum(PERWT[LABFORCE == '1']),
    num_unemployed = sum(PERWT[EMPSTAT == '2']),
    num_employed = sum(PERWT[EMPSTAT == '1']),
    num_ftyr = sum(PERWT[ftyr == 1]),
    num_ft = sum(PERWT[EMPSTAT == '1'
                       & UHRSWORK >= 35]), # Different from FTYR.
    num_pt = sum(PERWT[EMPSTAT == '1'
                       & UHRSWORK < 35]),
    num_lowend = sum(PERWT[EMPSTAT == '1'
                           & low_end == 1]),
    num_noncollege = sum(PERWT[EMPSTAT == '1'
                               & noncollege == 1]),
    lfpr = num_lab_force / num,
    pct_nilf = num_nilf / num,
    urate = num_unemployed / num_lab_force,
    pct_employed = num_employed / num_lab_force,
    epop = num_employed / num,
    pct_ftyr = num_ftyr / num_employed,
    pct_ft = num_ft / num_employed,
    pct_pt = num_pt / num_employed,
    pct_lowend = num_lowend / num_employed,
    pct_noncollege = num_noncollege / num_employed,
    # Only want earnings for those employed FTYR.
    per25_ftyr_earn = quantile(rep(INCEARN[ftyr == 1],
                                   times = PERWT[ftyr == 1]),
                               probs = 0.25, na.rm = TRUE),
    med_ftyr_earn = median(rep(INCEARN[ftyr == 1],
                               times = PERWT[ftyr == 1]),
                           na.rm = TRUE),
    per75_ftyr_earn = quantile(rep(INCEARN[ftyr == 1],
                                   times = PERWT[ftyr == 1]),
                               probs = 0.75, na.rm = TRUE),

    # Demographics
    ever_marr = sum(PERWT[MARST != '6']),
    men = sum(PERWT[SEX == '1']),
    women = sum(PERWT[SEX == '2']),
    white = sum(PERWT[RACE == '1']),
    black = sum(PERWT[RACE == '2']),
    natam = sum(PERWT[RACE == '3']),
    asian = sum(PERWT[RACE %in% c('4', '5', '6')]),
    hispan = sum(PERWT[HISPAN != '0']), # No one has value of '9' (not report)
    pct_ever_marr = ever_marr / num,
    pct_men = men / num,
    pct_women = women / num,
    pct_white = white / num,
    pct_black = black / num,
    pct_natam = natam / num,
    pct_asian = asian / num,
    pct_hispan = hispan / num
  ) %>%
  ungroup() %>%
  filter(unwgt_num >= 100)

# Create major-level dataset summarizing data for only recent college grads whom
# are currently employed FTYR.
MAJ_recent_grads_ftyr = recent_grads_ftyr %>%
  group_by(major_category, major) %>%
  summarize(
    unwgt_num = n(),
    num = sum(PERWT),

    # Edu info
    num_grad = sum(PERWT[GRADEATTD == '70']), # Includes working grad students.
    num_went_grad = sum(PERWT[EDUCD %in% c('114', '115', '116')
                              & SCHOOL == '1']),
    num_no_grad = sum(PERWT[!EDUCD %in% c('114', '115', '116')
                            & SCHOOL == '1']),
    pct = num / WGT_TOT_RECENT_GRADS_FTYR,
    pct_grad = num_grad / num,
    pct_went_grad = num_went_grad / num,
    pct_no_grad = num_no_grad / num,

    # Labor market info
    num_lowend = sum(PERWT[EMPSTAT == '1'
                           & low_end == 1]),
    num_noncollege = sum(PERWT[EMPSTAT == '1'
                               & noncollege == 1]),
    pct_lowend = num_lowend / num,
    pct_noncollege = num_noncollege / num,
    # Only want earnings for those employed FTYR.
    per25_ftyr_earn = quantile(rep(INCEARN,
                                   times = PERWT),
                               probs = 0.25, na.rm = TRUE),
    med_ftyr_earn = median(rep(INCEARN,
                               times = PERWT),
                           na.rm = TRUE),
    per75_ftyr_earn = quantile(rep(INCEARN,
                                   times = PERWT),
                               probs = 0.75, na.rm = TRUE),

    # Demographics
    ever_marr = sum(PERWT[MARST != '6']),
    men = sum(PERWT[SEX == '1']),
    women = sum(PERWT[SEX == '2']),
    white = sum(PERWT[RACE == '1']),
    black = sum(PERWT[RACE == '2']),
    natam = sum(PERWT[RACE == '3']),
    asian = sum(PERWT[RACE %in% c('4', '5', '6')]),
    hispan = sum(PERWT[HISPAN != '0']), # No one has value of '9' (not report)
    pct_ever_marr = ever_marr / num,
    pct_men = men / num,
    pct_women = women / num,
    pct_white = white / num,
    pct_black = black / num,
    pct_natam = natam / num,
    pct_asian = asian / num,
    pct_hispan = hispan / num
  ) %>%
  ungroup() %>%
  filter(unwgt_num >= 100)


##############
### Export ###
##############

write.csv(x = MAJ_recent_grads,
          file = './data/processed/MAJORS_recent_grads.csv')

write.csv(MAJ_recent_grads_ftyr,
          './data/processed/MAJORS_recent_grads_ftyr.csv')

write.csv(MAJ_recent_grads_ftyr,
          '../visual-majors-app/data/MAJORS_recent_grads_ftyr.csv')
