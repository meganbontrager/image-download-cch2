# Bulk downloading images from the CCH2 website
# Megan Bontrager
# mgbontrager@gmail.com
# 5 March 2019

library(tidyverse)

# To start, download the specimen records in the darwin core format for each species or genus of interest
# I downloaded these manually
# This script assumes that the folders (i.e. "SymbOutput_2019-03-05_154323_DwC-A") that you downloaded are all in a directory called cch2_records

# First, read in all the occurrence files and merge them together
# This lists all files in the directory "cch2_records" and directories within that that end in "occurrences.csv"
# recursive = TRUE searches nested directories
# full.names = TRUE pulls the paths to the files, not just the file names
occur_list = list.files(path = "cch2_records", pattern = "*occurrences.csv", recursive = TRUE, full.names = TRUE); occur_list

# Read in each of these csv files and bind them together
occur_all = bind_rows(lapply(occur_list, read_csv))
# You may get warnings about invalid date formats, this is ok. 
# It's just that specimens that have only year-month or year documented have zeros for month and/or day, and R is alerting you that this is weird
# Note that I don't recommend editing these csvs in excel because excel sometimes does funny things to date columns

# I want to sort images by species, so I've made a table that matches the species name on the specimen to the taxonomic groups that we're using
species_lookup = read_csv("data/species_lookup.csv")
# This is a csv that has all unique values in the scientificName column of the occurrence data in one column, and the names of the folders that I want those images to go into in another column
# i.e.
# scientificName                                species 
# Caulanthus amplexicaulis var. amplexicaulis   c_amplexicaulis
# Caulanthus anceps                             c_anceps
occur_all = left_join(occur_all, species_lookup)
# This joins on a new column that has the names of the folders that I want images to go into
sum(is.na(as.factor(occur_all$folder)))
# Make sure every potential specimen is assigned to a folder

# You could also just sort images by the exact scientific names, rather than making custom folder assignments 
# I didn't do this because I wanted synonyms, vars etc. to be put in the same species-level folder
# But if you wanted to, you could modify later steps to put the files in folders based on values in the scientificName or genus instead of the above section
# If you do this, you could create the directories with the following (I'm pretty sure this will give a warning and not overwrite an existing folder)
# for (i in 1: length(unique(occur_all$scientificName))) {
#   dir.create(path = paste0("processed_images/", unique(occur_all$scientificName)[i]))
# }

# Repeat the file reading and combining process for the image lists
image_list = list.files(path = "cch2_records", pattern = "*images.csv", recursive = TRUE, full.names = TRUE); image_list
image_all = bind_rows(lapply(image_list, read_csv))

# Join the specimen records with their image data, when available
occur_image = left_join(occur_all, image_all, by = c("id" = "coreid"))

# Check which images have already been downloaded (if any)
# This assumes these images live in subfolders a directory called "processed_images" and are named by their core ids
done_list = data.frame(file = list.files(path = "processed_images", pattern = "*.jpg", recursive = TRUE)) %>% 
  separate(file, into = c("subfolder", "id", "extension"), sep = c("\\/|\\.")) %>% 
  select(id) %>% 
  # Here I'm getting rid of specimen images that we have from Cal Academy, which aren't going to be on the CCH2 website
  filter(!str_detect(id, "^CAS")) %>% 
  mutate(id = as.numeric(id)); done_list

# Create a list of images to download that excludes these ones that are already done.
dl_list = anti_join(occur_image, done_list) %>% 
  filter(!is.na(accessURI))

# Check that the number of images to download = the number of images available - the number of images we already have
nrow(dl_list) == nrow(image_all) - nrow(done_list) 
# Should be true

# Now download each of these files
# This puts the downloaded files in subfolders based on the folder column merged on above, named by the id column, in a folder called "processed_images"
# Could substitute scientificName or genus for folder in the below command if you've made those directories above
# Note that the subfolders must already exist, otherwise you'll get a "file not found" error
for (i in 1:nrow(dl_list)) {
  download.file(url = dl_list$accessURI[i], method = "auto", destfile = paste("processed_images", "/", dl_list$folder[i], "/", dl_list$id[i], ".jpg", sep = ""))
}


