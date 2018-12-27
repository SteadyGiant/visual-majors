# Makes static & dynamic charts of median full-time (year-round) earnings.


##############
### Prelim ###
##############

# Get the dev versions of `ggplot2` & `plotly`
# library(devtools)
# devtools::install_github('tidyverse/ggplot2')
# devtools::install_github('ropensci/plotly')

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(grDevices)
  library(htmlwidgets)
  library(plotly)
  library(RColorBrewer)
  library(scales)
  library(stringr)
})

# Create function that will round dollar amounts displayed in scatter tooltips.
rounded_usd = scales::dollar_format(largest_with_cents = 0)

# `htmlwidgets::saveWidget` has a wacky `file` argument. Here's a fix.
# https://github.com/ramnathv/htmlwidgets/issues/299#issuecomment-375058928
saveWidgetFix <- function (widget, file, ...) {
  ## A wrapper to saveWidget which compensates for arguable BUG in saveWidget
  # which requires `file` to be in current working directory.
  wd <- getwd()
  on.exit(setwd(wd))
  outDir <- dirname(file)
  file <- basename(file)
  setwd(outDir);

  saveWidget(widget, file = file, ...)
}

# Create lighter palette for bar chart.
getPalette =
  RColorBrewer::brewer.pal(n = 12, name = 'Set3') %>%
  grDevices::colorRampPalette()

MAJ_recent_grads_ftyr =
  read.csv('./data/processed/MAJORS_recent_grads_ftyr.csv') %>%
  as_tibble()

# Calculate 1.1x max of chosen outcome, for scaling the axis.
bar_max = MAJ_recent_grads_ftyr %>%
  pull(med_ftyr_earn) %>%
  max() %>%
  `*`(1.1) %>%
  round(digits = -3)


#############
### Plots ###
#############

# Static bar chart
static_bar =
  ggplot(
    data = MAJ_recent_grads_ftyr,
    mapping = aes(
      x = reorder(major, med_ftyr_earn),
      y = med_ftyr_earn,
      fill = major_category
    )
  ) +
  geom_bar(stat = 'identity') +
  geom_text(
    mapping = aes(
      label = stringr::str_sub(string = major, start = 1, end = 20)
    ),
    color = 'black', fontface = 'bold', hjust = 1, size = 2
  ) +
  coord_flip() +
  scale_x_discrete(labels = NULL) +
  scale_y_continuous(
    expand = c(0, 0),
    # Scale axis to be 1.1x longer than max of chosen outcome.
    limits = c(0, bar_max),
    labels = scales::dollar) +
  labs(
    title = 'Median Full-time Earnings (2015-17)',
    subtitle = 'Ages 27 & under, 2017 dollars',
    caption = 'Source: ACS 1-year PUMS (2015, 2016, & 2017) via IPUMS',
    x = '', y = '', fill = '', color = '') +
  facet_wrap(~major_category, scales = 'free_y') +
  theme_bw() +
  theme(
    axis.ticks.y = element_blank(),
    strip.background = element_blank(),
    panel.border = element_rect(colour = "black"),
    legend.position = 'none',
    strip.text = element_text(hjust = 0, face = 'bold'),
    plot.title = element_text(hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5),
    plot.caption = element_text(size = 12, face = 'bold')
  ) +
  # Add custom palette.
  scale_fill_manual(values = getPalette(16))

# Interactive scatterplot

# ggthemes::theme_few() ignores legend text even though this website suggests
# it shouldn't: https://yutannihilation.github.io/allYourFigureAreBelongToUs/ggthemes/
# ggplotly() ignores captions & subtitles.
# https://github.com/ropensci/plotly/issues/799
# Consider using plotly's `annotations` feature:
# https://stackoverflow.com/questions/45103559/plotly-adding-a-source-or-caption-to-a-chart
# https://plot.ly/r/reference/#Layout_and_layout_style_objects
interact_scatter = (

  ggplot(
    data = MAJ_recent_grads_ftyr,
    mapping = aes(
      x = num,
      y = med_ftyr_earn,
      fill = major_category,
      color = major_category,
      # How to tooltip w/ ggplotly
      # https://stackoverflow.com/questions/34605919/formatting-mouse-over-labels-in-plotly-when-using-ggplotly
      text = paste(
        'Major:', '<b>', stringr::str_to_title(major), '</b>',
        '<br>',
        'Category:', major_category,
        '<br>',
        'Median Full-time Earnings:', rounded_usd(med_ftyr_earn),
        '<br>',
        '# of Graduates:', scales::comma(num)))) +
    # ggplot2 is weird.
    # https://stackoverflow.com/questions/45376877/scatterplot-fill-doesnt-change-in-ggplot2-even-when-specified
    geom_point(shape = 21) +
    scale_y_continuous(labels = scales::dollar) +
    scale_x_continuous(labels = scales::comma) +
    labs(
      title = 'Median Full-time Earnings (2015-17)',
      subtitle = 'Ages 27 & under, 2017 dollars',
      x = '# of Graduates', y = 'Median Full-time Earnings',
      fill = '', color = '',
      caption = 'Source: ACS 1-year PUMS (2015, 2016, & 2017) via IPUMS') +
    # ggthemes::theme_stata() +
    theme_bw() +
    theme(
      axis.ticks.y = element_blank(),
      strip.background = element_blank(),
      panel.border = element_rect(colour = "black"),
      legend.position = 'none',
      strip.text = element_text(hjust = 0, face = 'bold'),
      plot.title = element_text(hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      plot.caption = element_text(size = 12, face = 'bold')
    )

) %>%
  ggplotly(tooltip = 'text', height = 800, width = 900)


# Interactive Bar Chart
interact_bar = (

  ggplot(
    data = MAJ_recent_grads_ftyr,
    mapping = aes(
      x = reorder(major, med_ftyr_earn),
      y = med_ftyr_earn,
      fill = major_category,
      text = paste(
        'Major:', '<b>', stringr::str_to_title(major), '</b>',
        '<br>',
        'Category:', major_category,
        '<br>',
        'Median Full-time Earnings:', rounded_usd(med_ftyr_earn),
        '<br>',
        '# of Graduates:', scales::comma(num)))) +
    geom_bar(stat = 'identity') +
    geom_text(
      mapping = aes(
        label = stringr::str_sub(string = major, start = 1, end = 20)),
      color = 'black', fontface = 'bold', hjust = 1, size = 2) +
    coord_flip() +
    scale_x_discrete(labels = NULL) +
    scale_y_continuous(
      expand = c(0, 0),
      limits = c(0, bar_max),
      labels = scales::dollar) +
    labs(
      title = 'Median Full-time Earnings (2015-17)',
      subtitle = 'Ages 27 & under, 2017 dollars',
      caption = 'Source: ACS 1-year PUMS (2015, 2016, & 2017) via IPUMS',
      x = '', y = '', fill = '', color = '') +
    facet_wrap(~major_category, scales = 'free_y') +
    theme_bw() +
    theme(
      # Removes weirdo y-axis labels that come out of nowhere.
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      strip.background = element_blank(),
      panel.border = element_rect(colour = "black"),
      legend.position = 'none',
      strip.text = element_text(hjust = 0, face = 'bold'),
      plot.title = element_text(hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5),
      plot.caption = element_text(size = 12, face = 'bold')) +
    # Add custom palette.
    scale_fill_manual(values = getPalette(16))

) %>%
  ggplotly(tooltip = 'text', height = 800, width = 900)


##############
### Export ###
##############

ggplot2::ggsave(plot = static_bar,
                height = 10, width = 12,
                file = './graphics/bar_med_ftyr_earn.png')

saveWidgetFix(widget = interact_scatter,
              file = './widgets/scatter_med_ftyr_earn_num.html')

saveWidgetFix(interact_bar,
              './widgets/bar_med_ftyr_earn.html')
