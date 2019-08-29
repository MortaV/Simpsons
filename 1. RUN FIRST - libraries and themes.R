# Libraries and theme -----------------------------------------------------

library(tidyverse)
library(scales)
library(extrafont)
library(magick)

#Custom colours for my graphs
colors_cust = c('#FED90F', '#D1B271', '#70D1FE', '#424F46', '#FED41D', '#F14E28', '#009DDC')

logo <- image_read("logo.png") 

theme <- theme_minimal() +
  theme(text = element_text(family = 'Gayathri'),
        axis.text = element_text(size = rel(1), 
                                 vjust = 0.5,
                                 hjust = 0.5),
        axis.title = element_text(size = rel(1.5), 
                                 vjust = 0.5,
                                 hjust = 0.5),
        plot.title = element_text(size = rel(3), 
                                  vjust = 0.5,
                                  hjust = 0.5,
                                  face = "bold",
                                  colour = colors_cust[2],
                                  family = 'Permanent Marker'),
        strip.text = element_text(size = rel(0.8), 
                                  vjust = 0.5,
                                  hjust = 0.5),
        legend.position = "bottom",
        legend.justification = "center")

