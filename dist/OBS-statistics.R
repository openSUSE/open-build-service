# We use ggplot2, a library that makes painting graphics much easier.
# You can check the types of graphs and examples code here: https://plot.ly/ggplot2

# REQUIRE NEEDED LIBRARIES, in case that you don't have then installed, use: install.packages("ggplot2")
library(ggplot2)
library(reshape2)
library(plotly)
# require scales library to show only the years in the dates axis, 
# in case that you don't have then installed, use: install.packages("scales")
library(scales)

# FORMAT GRAPHS, to export in 2000x1200 and not valid for the pie charts
theme_set(theme_gray(base_size = 56))

# NUMBER OF USERS GRAPH

# Read users data and save it in a dataframe variable
dataUsers <- read.csv('number_users.txt')

# In this case, we are going to use a simple geom_line without points

users_data <- data.frame(
  users = dataUsers$users,
  date = as.Date(dataUsers$date, format = "%Y-%m-%d") # convert String to Date
)

ggplot(data=users_data, aes(x=date, y=users)) +
  geom_line(size=3)


###############################################################################################

# NUMBER OF BS REQUESTS GRAPH

# Read bs_requests data and save it in a dataframe variable
dataBsRequests <- read.csv('number_bs_requests.txt')

bs_requests_data <- data.frame(
  bs_requests = dataBsRequests$bs_requests,
  date = as.Date(dataBsRequests$date, format = "%Y-%m-%d") # convert String to Date
)

ggplot(data=bs_requests_data, aes(x=date, y=bs_requests)) +
  geom_line(size=1, colour="red")


# NUMBER OF BS REQUESTS FROM 2015

# Take subset with the data from 2015
bs_requests_data_from_2015 <- subset(bs_requests_data, date >= as.Date("2015-01-01") )

# We scale to show only the year. 
# Otherwise, as this period of time if shorter it will show 2015-01, 2015-07, 2016-01,... on the date axis
ggplot(data=bs_requests_data_from_2015, aes(x=date, y=bs_requests)) +
  geom_line() +
  scale_x_date(breaks = date_breaks("1 years"), labels = date_format("%Y"))


# SEVERAL BS REQUESTS

# for this graphs the font has to be decreased and EXPORT IT in 2000x1000
theme_set(theme_gray(base_size = 36))

several_bs_requests_data <-
  data.frame(
    all = dataBsRequests$bs_requests,
    openSUSE_Factory = read.csv('number_bs_requests_for_openSUSE:Factory.txt')$bs_requests,
    openSUSE_Maintenance = read.csv('number_bs_requests_for_openSUSE:Maintenance.txt')$bs_requests,
    openSUSE_Leap_42.1 = read.csv('number_bs_requests_for_openSUSE:Leap:42.1.txt')$bs_requests,
    openSUSE_Leap_42.2 = read.csv('number_bs_requests_for_openSUSE:Leap:42.2.txt')$bs_requests,
    openSUSE_Leap_42.3 = read.csv('number_bs_requests_for_openSUSE:Leap:42.3.txt')$bs_requests,
    GNOME_Factory = read.csv('number_bs_requests_for_GNOME:Factory.txt')$bs_requests,
    devel_languages = read.csv('number_bs_requests_for_devel:languages.txt')$bs_requests,
    date = as.Date(dataBsRequests$date, format = "%Y-%m-%d")
  )

test_data_long <- melt(several_bs_requests_data, id="date")  # convert to long format

ggplot(data=test_data_long,
       aes(x=date, y=value, colour=variable)) +
  geom_line(size=1) +
  theme(legend.text=element_text(size=26),legend.key.height=unit(2,"line"))


# SEVERAL BS REQUESTS FROM 2015

# Take subset with the data from 2015
several_bs_requests_data_from_2015 <- subset(several_bs_requests_data, date >= as.Date("2015-01-01") )

test_data_long <- melt(several_bs_requests_data_from_2015, id="date")  # convert to long format

ggplot(data=test_data_long,
       aes(x=date, y=value, colour=variable)) +
  geom_line()


# NUMBER OF ACTIVE PROJECTS
# reset font and EXPORT IT in 2000x1200
theme_set(theme_gray(base_size = 56))

dataProjects <- read.csv('number_projects_bs_requests.txt')
projects_data <- data.frame(
  number_projects = dataProjects$projects_bs_requests,
  date = as.Date(dataProjects$date, format = "%Y-%m-%d")
)

ggplot(data=projects_data,
       aes(x=date, y=number_projects)) +
  geom_line(size=2, color="#0ECBD9")


# NUMBER OF ACTIVE PROJECTS VS ACTIVITY

# for this graphs the font has to be decreased and EXPORT IT in 2000x1000
theme_set(theme_gray(base_size = 46))

dataBsRequests <- read.csv('number_bs_requests.txt')

bs_requests_data <- data.frame(
  bs_requests = dataBsRequests$bs_requests,
  date = as.Date(dataBsRequests$date, format = "%Y-%m-%d") # convert String to Date
)

dataBsRequestsFrom2013 <- subset(bs_requests_data, date >= as.Date("2013-01-01") )

projects_bs_requests_data <- data.frame(
    all = dataBsRequestsFrom2013$bs_requests,
    number_projects = read.csv('number_projects_bs_requests.txt')$projects_bs_requests,
    date = as.Date(dataBsRequestsFrom2013$date, format = "%Y-%m-%d")
  )

test_data_long <- melt(projects_bs_requests_data, id="date")  # convert to long format

ggplot(data=test_data_long,
       aes(x=date, y=value, colour=variable)) +
  geom_line(size=1) +
  theme(legend.text=element_text(size=28),legend.key.height=unit(2,"line"))


# NUMBER OF ACTIVE PROJECTS VS DIFF ACTIVITY

projects_diff_bs_requests_data <- data.frame(
  diff_all = c(0,diff(dataBsRequestsFrom2013$bs_requests)),
  number_projects = read.csv('number_projects_bs_requests.txt')$projects_bs_requests,
  date = as.Date(dataBsRequestsFrom2013$date, format = "%Y-%m-%d")
)

test_data_long <- melt(projects_diff_bs_requests_data, id="date")  # convert to long format

ggplot(data=test_data_long,
       aes(x=date, y=value, colour=variable)) +
  geom_line(size=2) +
  theme(legend.text=element_text(size=28),legend.key.height=unit(2,"line"))

# BS REQUEST CORRELATION

diff_all <- projects_diff_bs_requests_data$diff_all
number_projects <- projects_diff_bs_requests_data$number_projects

# get correlation value
cor(diff_all, number_projects)

# paint the correlation graph
ccf(diff_all, number_projects)


###############################################################################################

# GITHUB

# PRs

# reset font and EXPORT IT in 2000x1200
theme_set(theme_gray(base_size = 56))

dataPrs <- read.csv('pull_requests_merged.csv')

prs_data <- data.frame(
  PRs = dataPrs$number_pull_requests_merged,
  date = as.Date(dataPrs$week, format = "%Y-%m-%d") # convert String to Date
)

ggplot(data=prs_data, aes(x=date, y=PRs)) +
  geom_line(size=2, color="#5F04B4")


# CODE FRECUENCY

# for this graphs the font has to be decreased and EXPORT IT in 2000x1000
theme_set(theme_gray(base_size = 46))

code_frequency <- read.csv('code_frequency.csv')

code_frequency_data <-
  data.frame(
    additions = code_frequency$additions,
    deletions = code_frequency$deletions,
    date = as.Date(code_frequency$date, format = "%Y-%m-%d")
  )

test_data_long <- melt(code_frequency_data, id="date")  # convert to long format

ggplot(data=test_data_long,
       aes(x=date, y=value, colour=variable)) +
  geom_line(size=1) +
  theme(legend.text=element_text(size=28),legend.key.height=unit(2,"line"))



# COMMIT ACTIVITY

# reset font and EXPORT IT in 2000x1200
theme_set(theme_gray(base_size = 56))

dataCommits <- read.csv('commit_activity.csv')

commits_data <- data.frame(
  commits = dataCommits$commits,
  date = as.Date(dataCommits$date, format = "%Y-%m-%d") # convert String to Date
)

ggplot(data=commits_data, aes(x=date, y=commits)) +
  geom_line(size=2, color="#04B404")



###############################################################################################

# BAR GRAPH FOR NUMBER OF BUILDS

# for this graphs the font has to be decreased and EXPORT IT in 2000x1000
theme_set(theme_gray(base_size = 38))

build <- data.frame(
  status = factor(c("unchanged", "unchanged", "unchanged", "unchanged", "failed", "failed", "failed", "failed", "succeeded", "succeeded", "succeeded", "succeeded")),
  hosts = factor(c("distributions", "home", "staging", "rest", "distributions", "home", "staging", "rest", "distributions", "home", "staging", "rest"), levels=c("distributions", "home", "staging", "rest")),
  builds = c(4000, 15300, 49000, 50000, 100, 5000, 800, 8800, 6200, 15000, 20000, 34000)
)

ggplot(data=build, aes(x=hosts, y=builds, fill=status)) +
  geom_bar(colour="black", stat="identity",
           position=position_dodge(),
           size=.5) +  # Thinner lines
  scale_fill_manual(values=c("#FF0000", "#04B404", "#0080FF")) +
  theme(legend.text=element_text(size=30),legend.key.height=unit(2,"line"))

###############################################################################################

# PIE CHART OF REQUESTS STATES

slices <- c(10763, 1684, 369727, 97, 44014, 5352, 46547)
lbls <- c("declined", "review", "accepted", "deleted", "revoked", "new", "superseded")
pct <- round(slices/sum(slices)*100, 2)
# add percents and %
lbls <- paste(paste(lbls, pct),"%",sep="")
# print the pie chart with a beautiful rainbow color
# cex is though to export the image in 2000x1200
pie(slices,labels = lbls, col=rainbow(length(lbls)), radius = 1, cex = 3)


###############################################################################################

# PIE CHART OF CODE LINES

slices <- c(217801, 30622, 33769)
lbls <- c("Code Lines", "Comment Lines", "Blank Lines")
pct <- round(slices/sum(slices)*100)
# add percents and %
lbls <- paste(paste(lbls, pct),"%",sep="")
# cex is though to export the image in 2000x1200 (to show it small)
pie(slices,labels = lbls, cex = 3)

# PIE CHART OF CODE LINES BY LANGUAGE

slices <- c(92288, 81912, 54648, 14854, 14913, 12827, 4470, 6280)
lbls <- c("Ruby", "Perl", "Python", "XML", "JavaScript", "shell script", "CSS", "Others")
pct <- round(slices/sum(slices)*100, 1)
# add percents and %
lbls <- paste(paste(lbls, pct),"%",sep="")
# print the pie chart with a beautiful rainbow color
# cex is though to export the image in 2000x1200
pie(slices,labels = lbls, col=rainbow(length(lbls)), radius = 1, cex = 3)
