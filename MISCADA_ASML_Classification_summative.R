# Load necessary packages
library(tidyverse)
library(caret)
library(ggcorrplot) # Correlation heatmap
library(pROC)    # ROC curve
# Read data
data <- read.csv("https://www.louisaslett.com/Courses/MISCADA/telecom.csv", stringsAsFactors = TRUE)
# Handle missing values (NA in TotalCharges)
data <- data %>%
  mutate(TotalCharges = as.numeric(as.character(TotalCharges))) %>%
  drop_na(TotalCharges)
data <- data %>%
  mutate(
    Contract = str_replace_all(Contract, " ", ".")  # Replace spaces with periods
  )
data <- data %>%
  mutate(
    PaymentMethod = str_replace_all(PaymentMethod, "[ ().]", "_")
  )
data <- data %>%
  mutate(
    PaymentMethod = str_replace_all(PaymentMethod, "_+", "_")
  )
data <- data %>%
  mutate(
    PaymentMethod = str_replace_all(PaymentMethod, "^_|_$", "")
  )
# Replace "-" with "_" in the Contract column
data <- data %>%
  mutate(
    Contract = str_replace_all(Contract, "-", "_")
  )


# Convert binary classification variables to 0/1
data <- data %>%
  mutate(
    Churn = ifelse(Churn == "Yes", 1, 0),
    Partner = ifelse(Partner == "Yes", 1, 0),
    Dependents = ifelse(Dependents == "Yes", 1, 0)
  )
# Perform one-hot encoding for multi-class variables
dummy_model <- dummyVars(~ gender + PaymentMethod + Contract + InternetService, data = data)
data_encoded <- predict(dummy_model, newdata = data) %>% as.data.frame()
data <- bind_cols(data, data_encoded) %>%
  select(-gender, -PaymentMethod, -Contract, -InternetService)



# Draw a bar chart of attrition rate distribution
ggplot(data, aes(x = factor(Churn), fill = factor(Churn))) +
  geom_bar() +
  labs(title = "Churn Distribution", x = "Churn", y = "Count") +
  scale_fill_manual(values = c("#66c2a5", "#fc8d62")) +
  theme_minimal()



# Draw a boxplot of tenure and drain
ggplot(data, aes(x = factor(Churn), y = tenure, fill = factor(Churn))) +
  geom_boxplot() +
  labs(title = "Tenure vs Churn", x = "Churn", y = "Tenure (Months)") +
  scale_fill_manual(values = c("#66c2a5", "#fc8d62")) +
  theme_minimal()

# Draw a boxplot of MonthlyCharges and drains
ggplot(data, aes(x = factor(Churn), y = MonthlyCharges, fill = factor(Churn))) +
  geom_boxplot() +
  labs(title = "Monthly Charges vs Churn", x = "Churn", y = "Monthly Charges") +
  scale_fill_manual(values = c("#66c2a5", "#fc8d62")) +
  theme_minimal()



# Stack bar chart of contract types and churn
ggplot(data, aes(x = ContractOne.year, fill = factor(Churn))) +
  geom_bar(position = "fill") +
  labs(title = "Contract Type vs Churn", x = "One-Year Contract", y = "Proportion") +
  scale_fill_manual(values = c("#66c2a5", "#fc8d62")) +
  theme_minimal()



# Calculate numerical feature correlations
numeric_data <- data %>% select(tenure, MonthlyCharges, TotalCharges)
corr_matrix <- cor(numeric_data)

# Draw a heat map
ggcorrplot(corr_matrix, 
           hc.order = TRUE, 
           lab = TRUE, 
           colors = c("#6D9EC1", "white", "#E46726")) +
  labs(title = "Correlation Heatmap of Numeric Features")



names(data) <- gsub(" ", "_", names(data))
set.seed(123)
split <- createDataPartition(data$Churn, p = 0.8, list = FALSE)
train_data <- data[split, ]
test_data <- data[-split, ]

library(randomForest)

# train model
rf_model <- randomForest(
  factor(Churn) ~ .,
  data = train_data,
  ntree = 100,
  importance = TRUE
)

# Predict and evaluate
predictions <- predict(rf_model, test_data)
confusionMatrix(predictions, factor(test_data$Churn))


# Get the prediction probability
prob_rf <- predict(rf_model, test_data, type = "prob")[, 2]
roc_obj <- roc(test_data$Churn, prob_rf)

# Draw the ROC curve
plot(roc_obj, 
     main = "ROC Curve for Random Forest",
     col = "#1c61b6",
     print.auc = TRUE,
     auc.polygon = TRUE)



# Importance of extracting features
importance <- importance(rf_model)
var_importance <- data.frame(
  Feature = rownames(importance),
  Importance = importance[, "MeanDecreaseGini"]
)

# Draw an importance bar chart
ggplot(var_importance, aes(x = reorder(Feature, Importance), y = Importance)) +
  geom_bar(stat = "identity", fill = "#66c2a5") +
  coord_flip() +
  labs(title = "Feature Importance", x = "Feature", y = "Importance (Gini)") +
  theme_minimal()

