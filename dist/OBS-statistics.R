# NUMBER OF USERS GRAPH

# Read users data and save it in a dataframe variable
dataUsers <- read.csv('number_users.txt')

# We use ggplot2, a library that makes painting graphics much easier.
# You can check the types of graphs and examples code here: https://plot.ly/ggplot2

# In this case, we are going to use a simple geom_line without points

# require library, in case that you don't have then installed, use: install.packages("ggplot2")
library(ggplot2)

users_data <- data.frame(
  users = dataUsers$users,
  date = as.Date(dataUsers$date, format = "%Y-%m-%d") # convert String to Date
)

ggplot(data=users_data, aes(x=date, y=users)) +
  geom_line()


###############################################################################################

# NUMBER OF BS REQUESTS GRAPH

# Read bs_requests data and save it in a dataframe variable
dataBsRequests <- read.csv('number_bs_requests.txt')

# In this case, we are going to use a simple geom_line without points

# require library, in case that you don't have then installed, use: install.packages("ggplot2")
library(ggplot2)

bs_requests_data <- data.frame(
  bs_requests = dataBsRequests$bs_requests,
  date = as.Date(dataBsRequests$date, format = "%Y-%m-%d") # convert String to Date
)

ggplot(data=bs_requests_data, aes(x=date, y=bs_requests)) +
  geom_line()

