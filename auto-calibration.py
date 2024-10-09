import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.datasets import load_iris
from sklearn.metrics import accuracy_score

# Load the Iris dataset
iris = load_iris()
X = iris.data
y = iris.target

# Split the dataset
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Create datasets for training and testing
dtrain = xgb.DMatrix(X_train, label=y_train)
dtest = xgb.DMatrix(X_test, label=y_test)

# Set up parameters for the model
params = {
    'objective': 'multi:softmax',  # Multiclass classification
    'num_class': 3,                # Number of classes
    'device': 'cuda',              # Use GPU for histogram-based training
    'eval_metric': 'mlogloss'
}

# Train the model
bst = xgb.train(params, dtrain, num_boost_round=100)

# Predict using the model
y_pred = bst.predict(dtest)

# Evaluate accuracy
accuracy = accuracy_score(y_test, y_pred)
print(f"Accuracy: {accuracy * 100:.2f}%")
