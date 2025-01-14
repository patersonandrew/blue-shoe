
########################################################
## Bi-Weekly Wear Test Data Management 
## ... an attempt to import the data and make it into a usable form for eas[ier] analysis
## by Teresa Fukuda
## 
##########################################################

# Part I. Load packages and import data

library(tidyverse) # hello tidyverse
library(janitor) # load janitor to clean up dataframe
library(lubridate) # load lubridate to work with dates and times

# I made this so that you can download the data from the Google Drive as a csv and import directly into here, no edits

biweeklydata <- read_csv("Bi-Weekly Wear Test Form.csv") # edit file name to match the downloaded file (the one I used to test this was edited with a bunch of fake data)

shoe_id_table <- read_csv("ShoeID_data_forR.csv") # table from google sheets of all participants and their shoe models and ID

presurvey_data <- read_csv("Pre Survey Data - Sheet1.csv") #all the presurvey data

mass_data <- read_csv("Shoe_mass_forR - Sheet1.csv") #this has the shoe weight data for before and after testing in grams

shoe_deets <- read_csv("ShoeID_data_forR - Sheet2.csv") # sheet 2 in the google sheet has the shoe details about rubber, abrasion, etc.


# Part II. Clean up the biweekly data, presurvey data and summarize into totals by name of user

clean_biweekly <- biweeklydata  %>% 
  clean_names(.)  %>%
  mutate_if(is.character, str_to_upper) # make all character labels uppercase

totals_biweekly <- clean_biweekly %>% 
  mutate("name"= `name_first_last`) %>% # This may need to be changed to match whatever is in the actual survey right now (if it was changed since this is confusing)
  mutate("steps"= `how_many_steps_were_taken_in_the_test_shoes_during_the_past_two_weeks`) %>% 
  mutate ("miles"= `how_many_miles`) %>% 
  mutate ("minutes"= `how_many_minutes_have_been_recorded_while_wearing_the_shoes`) %>% 
  select(name, steps, miles, minutes) %>% 
  group_by(name) %>% 
  summarize (steps= sum(steps),
             miles= sum(miles)) %>% #,
             #minutes=sum(minutes)) 
  mutate ("steps to miles" = steps/2250) %>% 
  mutate ("miles to steps" = miles*2250)# assuming 2250 steps on average per mile

clean_pre <- presurvey_data  %>%
  rename("name"= 'X1') %>% 
  clean_names(.) %>% 
  mutate ("gait" = question_11) %>% 
  select(name,age, weight, gait) %>% 
  mutate_if(is.character, str_to_upper) # takes name, age, weight, and gait from pre-survey; makes data ALL CAPS

  

# Part III. Clean up shoe ID data; keep participant, shoe, model 

clean_shoe_ID <- shoe_id_table %>% 
  clean_names(.) %>% 
  mutate (name=participant) %>% 
  mutate_if(is.character, str_to_upper) %>% 
  select(shoe_id_left,shoe_id_right,model,name) %>% 
  mutate(shoe_id_left=gsub("-","",.$shoe_id_left)) %>% 
  mutate(shoe_id_right=gsub("-","",.$shoe_id_right)) %>%
  mutate(shoe_id_left=gsub(" ","",.$shoe_id_left)) %>% 
  mutate(shoe_id_right=gsub(" ","",.$shoe_id_right)) %>% 
  gather("delete","shoe_ID", 1:2)
  

# Part IV. Merge shoe ID data with each users reported miles/steps/minutes

wear_data_joined <- full_join(totals_biweekly,clean_shoe_ID)

pre_data_joined <- full_join(wear_data_joined,clean_pre)


# Part V. Clean up mass data and join with shoe traits (rubber type, abrasion rating, etc.)

# clean up shoe details (rubber type, hardness, abrasion, geometry)

clean_shoedeets <- shoe_deets %>% 
  select(Model, hardness, abrasion, rubber_type,geometry) %>% 
  clean_names(.) %>% 
  mutate_if(is.character, str_to_upper)

# make mass data tidy, then find average of pre and post mass, then find difference

clean_mass <- mass_data %>% 
  gather ("trial","mass",3:12) %>%
  mutate("prepost"= case_when(trial=="pre1"|trial=="pre2"|trial=="pre3"|trial=="pre4"|trial=="pre5" ~ "pre", TRUE~"post")) %>% 
  group_by(`Shoe ID`,`prepost`) %>% 
  mutate(mass= as.double(mass))  %>% 
  summarize("average"=mean(mass)) %>%  # averages of pre and post data for each shoe ID
  spread(.,prepost, average) %>% # separate pre and post columns
  mutate("grams_lost"= pre-post) %>% 
  mutate("shoe_ID"= `Shoe ID`) %>% 
  select (-c('Shoe ID'))



# Part VI. Add the post-wear measurement data and calculate the loss per mile, loss per step, normalize by body weight??

# join the wear data and the pre and post mass data

mass_data_joined <- full_join(pre_data_joined,clean_mass)

full_data_joined <- full_join(mass_data_joined, clean_shoedeets) %>%  #join all pre and post mass data, participant age/weight/name, shoe model/rubber/abrasion
  select (-c('delete'))
  
step_calculations <- full_data_joined %>% 
  mutate("km"= miles*1.60934) %>% 
  mutate("g_per_km"= grams_lost/km) %>% 
  mutate("weight_kg"= weight*0.453592) %>% 
  mutate("g_per_km_per_kg"=g_per_km/weight_kg)

#compare steps to miles and choose "best"?


# Part VII. Visualize data loss per style, loss per rubber type, overall loss per mile, loss per mile per pound of force?
#age_vis <- ggplot(clean_pre, aes(x=age)) + 
#geom_histogram()

### grams loss per shoe for each style###

#histogram of grams lost for all shoes
grams_per_shoe <- ggplot(step_calculations, aes(x=grams_lost))+
  geom_histogram()

grams_per_shoe


#histogram of grams/km broken up by style-- not particularly useful because of so few data points per style
per_shoe_style <- step_calculations %>% 
  group_by(model) %>% 
  ggplot(., aes(x=g_per_km))+
  geom_histogram()+
  facet_wrap(~model)
per_shoe_style

#### grams loss per shoe for each rubber type across styles ###



### overall loss per km ####
#histogram of grams/km for all shoes
grams_per_shoe <- ggplot(step_calculations, aes(x=g_per_km))+
  geom_histogram()
grams_per_shoe
### loss per km per kg body weight ####

#histogram of grams/km/kg weight for all shoes
grams_per_bodyweight <- ggplot(step_calculations, aes(x=g_per_km_per_kg))+
  geom_histogram()
grams_per_bodyweight
### loss per km per kg body weight by abrasion rating ###
grams_per_bodyweight_abrasion <- ggplot(step_calculations, aes(x=g_per_km_per_kg))+
  geom_histogram()+
  facet_wrap(~abrasion)
grams_per_bodyweight_abrasion
### loss per km per kg body weight by hardness rating ###
grams_per_bodyweight_hardness <- ggplot(step_calculations, aes(x=g_per_km_per_kg))+
  geom_histogram()+
  facet_wrap(~hardness)
grams_per_bodyweight_hardness

#Part VIII. Statistical testing

# Hardness, abrasion, rubber type, geometry
# Rate of shoe abrasion? g/km/kg/time across all shoes to see if it's linear relationship (time v. abrasion rate)

# some summary information

summary_geometry <- full_data_joined %>% 
  group_by(geometry) %>% 
  summarize("count"= n())

# t-tests among each parameter? (within geometry, abrasion, hardness, rubber type)
# some sort of test across all parameters?
# comparing mass loss and change in tread depth
# comparing if rate of plastic losses changes with more wear. So, do shoes lose more mass per mile in the first 3 months of wear or next 3?
