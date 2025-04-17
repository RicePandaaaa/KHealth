import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import KFold, cross_val_score
from sklearn.metrics import mean_squared_error, r2_score
import warnings

# Ignore potential warnings from XGBoost for cleaner output
warnings.filterwarnings('ignore', category=UserWarning, module='xgboost')

# --- Configuration ---
FILE_PATH = 'model_train.csv'
# *** CORRECTED: Predicting Concentration based on Measurement ***
TARGET_COLUMN = 'Concentration'
FEATURE_COLUMNS = ['Measurement'] # Use original Measurement and its square
N_SPLITS = 5      # Number of folds for K-Fold Cross-Validation
RANDOM_STATE = 42 # For reproducible KFold splits

# --- Load Data ---
try:
    df = pd.read_csv(FILE_PATH)
    print(f"Successfully loaded data from {FILE_PATH}")
    print(f"Data shape: {df.shape}")
except FileNotFoundError:
    print(f"Error: File not found at {FILE_PATH}")
    print("Please ensure the file 'processed_data_for_xgboost.csv' is in the same directory as the script.")
    exit()
except Exception as e:
    print(f"An error occurred while loading the data: {e}")
    exit()

# --- Feature Engineering ---
# Create the squared Measurement feature
df['Measurement_sq'] = df['Measurement'] ** 2
print("\nAdded 'Measurement_sq' feature.")

# --- Prepare Data ---
# Check if required columns exist
if TARGET_COLUMN not in df.columns or not all(col in df.columns for col in ['Measurement', 'Measurement_sq']):
     print(f"Error: Required columns not found in the DataFrame.")
     exit()

# Define features (X) and target (y)
X = df[FEATURE_COLUMNS]
y = df[TARGET_COLUMN]

print(f"\nFeatures (X): {', '.join(FEATURE_COLUMNS)}")
print(f"Target (y): {TARGET_COLUMN}")

# --- Initialize Model ---
# Initialize the XGBoost Regressor model
model = xgb.XGBRegressor(objective='reg:squarederror',
                         n_estimators=100,
                         learning_rate=0.1,
                         max_depth=3,
                         random_state=RANDOM_STATE)

# --- Perform K-Fold Cross-Validation ---
print(f"\nPerforming {N_SPLITS}-Fold Cross-Validation...")
kf = KFold(n_splits=N_SPLITS, shuffle=True, random_state=RANDOM_STATE)

# Use cross_val_score to get scores for each fold
cv_scores_mse = cross_val_score(model, X, y, cv=kf, scoring='neg_mean_squared_error')
cv_scores_r2 = cross_val_score(model, X, y, cv=kf, scoring='r2')

# Calculate average scores and standard deviation
mean_mse = -np.mean(cv_scores_mse) # Invert negative MSE
std_mse = np.std(cv_scores_mse)
mean_r2 = np.mean(cv_scores_r2)
std_r2 = np.std(cv_scores_r2)

print("Cross-Validation Results (Predicting Concentration using Measurement + Measurement_sq):")
print(f"  Mean Squared Error (MSE): {mean_mse:.4f} (+/- {std_mse:.4f})")
print(f"  R-squared (R²):         {mean_r2:.4f} (+/- {std_r2:.4f})")

# --- Train Final Model on All Data ---
print("\nTraining final model on the entire dataset using Measurement + Measurement_sq...")
final_model = xgb.XGBRegressor(objective='reg:squarederror',
                               n_estimators=100,
                               learning_rate=0.1,
                               max_depth=3,
                               random_state=RANDOM_STATE)
final_model.fit(X, y)
print("Final model training complete.")
print("This 'final_model' can be saved and used for predicting Concentration based on Measurement and Measurement_sq.")

# --- Example Prediction with Final Model (Optional) ---
# You can uncomment and modify this section to predict a new value using the final model
# example_measurement = 2.28
# new_data = pd.DataFrame({'Measurement': [example_measurement], 'Measurement_sq': [example_measurement**2]})
# predicted_concentration = final_model.predict(new_data)
# print(f"\nPredicted concentration for measurement {example_measurement} using final model: {predicted_concentration[0]:.2f}")


print("\nScript finished.")