
simpsons <- readr::read_delim("https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2019/2019-08-27/simpsons-guests.csv", delim = "|", quote = "")

View(simpsons)

roles_by_star <- simpsons %>%
    group_by(guest_star) %>%
    summarize(appearances = n(),
              distinct_roles = n_distinct(role)) 

View(roles_by_star)

roles_by_star %>%
    top_n(10, distinct_roles) %>%
    ggplot(aes(x = fct_reorder(guest_star, distinct_roles), y = distinct_roles)) +
    geom_bar(stat = "identity", fill = colors_cust[1]) +
    theme +
    coord_flip()

grid::grid.raster(logo,  x = 0.90, y = 0.90, just = c('center', 'center'), width = unit(1, 'inches'))
