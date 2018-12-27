# Runs the scripts necessary to produce all output of this project.
# See 'requirements.txt' for software dependencies and versions.

# Process microdata from IPUMS into major-level datasets.
source('./src/R/process_ipums.R', local = new.env())

# Generate plots and widgets using major-level data.
source('./src/R/plot.R', local = new.env())
