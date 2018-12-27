library(rmarkdown)

rmarkdown::render(input = './src/Markdown/journey-visual-majors.Rmd',
                  output_format = 'html_document',
                  output_file = 'journey-visual-majors.html',
                  output_dir = './reports/')
