# Install dependencies (for Colab, remove if running locally)
# !pip install prophet scikit-learn openpyxl xlrd xgboost --quiet

# Imports
import os, zipfile, json
import pandas as pd
import numpy as np
from prophet import Prophet
from sklearn.metrics import mean_absolute_error, mean_squared_error
from xgboost import XGBRegressor
import matplotlib.pyplot as plt

# Setup paths
data_dir = './EnergyData'  # Update to '/content/drive/MyDrive/EnergyData' for Colab
extracted_dir = os.path.join(data_dir, 'unzipped')
os.makedirs(extracted_dir, exist_ok=True)

# Extract zip files
for file in os.listdir(data_dir):
    if file.endswith('.zip'):
        zip_path = os.path.join(data_dir, file)
        extract_target = os.path.join(extracted_dir, os.path.splitext(file)[0])
        if not os.path.exists(extract_target):
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_target)

# Load CSV/Excel files
def load_data_file(filepath):
    try:
        ext = os.path.splitext(filepath)[1].lower()
        if ext == '.csv':
            df = pd.read_csv(filepath)
        elif ext in ['.xls', '.xlsx']:
            df = pd.read_excel(filepath)
        else:
            return None

        df.columns = df.columns.str.strip()
        df = df.dropna(axis=1, how='all')

        datetime_col = next((col for col in df.columns if pd.to_datetime(df[col], errors='coerce').notna().mean() > 0.9), None)
        if not datetime_col: return None

        df['ds'] = pd.to_datetime(df[datetime_col], errors='coerce').dt.tz_localize(None)
        df = df.dropna(subset=['ds'])

        value_col = next((col for col in df.columns if col != datetime_col and pd.to_numeric(df[col], errors='coerce').notna().mean() > 0.9), None)
        if not value_col: return None

        df['y'] = pd.to_numeric(df[value_col], errors='coerce')
        df = df[['ds', 'y']].dropna()
        df = df[df['y'] > 0]
        return df
    except:
        return None

# Gather all files
all_files = [os.path.join(root, file)
             for root, _, files in os.walk(extracted_dir)
             for file in files
             if file.endswith(('.csv', '.xls', '.xlsx'))]

dfs = [load_data_file(f) for f in all_files if load_data_file(f) is not None]
if not dfs:
    raise ValueError("❌ No valid data files found.")
df = pd.concat(dfs).drop_duplicates(subset='ds').sort_values('ds')

# Define cutoff for train/test split
cutoff = df['ds'].max() - pd.Timedelta(hours=48)
train_df = df[df['ds'] < cutoff].copy()
test_df = df[df['ds'] >= cutoff].copy()

# Feature engineering
def add_features(df):
    df = df.sort_values('ds')
    df['hour'] = df['ds'].dt.hour
    df['dayofweek'] = df['ds'].dt.dayofweek
    df['month'] = df['ds'].dt.month
    df['lag_1'] = df['y'].shift(1)
    df['lag_24'] = df['y'].shift(24)
    df['lag_168'] = df['y'].shift(168)
    df['rolling_mean_24'] = df['y'].rolling(24).mean()
    df['rolling_std_24'] = df['y'].rolling(24).std()
    return df.dropna()

train_df = add_features(train_df)
test_df = add_features(test_df)

# Prophet model
prophet_model = Prophet(daily_seasonality=True, weekly_seasonality=True, yearly_seasonality=True)
prophet_model.fit(train_df[['ds', 'y']])

future = test_df[['ds']]
forecast = prophet_model.predict(future)[['ds', 'yhat']]

# Residual correction with XGBoost
merged_train = pd.merge(train_df, prophet_model.predict(train_df[['ds']])[['ds', 'yhat']], on='ds', how='inner')
merged_train['residual'] = merged_train['y'] - merged_train['yhat']

feature_cols = ['hour', 'dayofweek', 'month', 'lag_1', 'lag_24', 'lag_168', 'rolling_mean_24', 'rolling_std_24']
X_train = merged_train[feature_cols]
y_train = merged_train['residual']

xgb = XGBRegressor(
    n_estimators=300,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    random_state=42
)
xgb.fit(X_train, y_train)

# Apply to test set
test_merged = pd.merge(test_df, forecast, on='ds')
test_merged['residual_pred'] = xgb.predict(test_merged[feature_cols])
test_merged['yhat_corrected'] = test_merged['yhat'] + test_merged['residual_pred']

# Evaluation
def smape(a, f):
    return 100/len(a) * np.sum(2 * np.abs(f - a) / (np.abs(a) + np.abs(f)))

mae = mean_absolute_error(test_merged['y'], test_merged['yhat_corrected'])
rmse = mean_squared_error(test_merged['y'], test_merged['yhat_corrected'])**0.5
mape = np.mean(np.abs((test_merged['y'] - test_merged['yhat_corrected']) / test_merged['y'])) * 100
smape_val = smape(test_merged['y'].values, test_merged['yhat_corrected'].values)

print("\n📊 Final Forecast Accuracy (Hybrid Prophet + XGBoost on Unseen Data):")
print(f"  MAE   = {mae:.2f}")
print(f"  RMSE  = {rmse:.2f}")
print(f"  MAPE  = {mape:.2f}%")
print(f"  SMAPE = {smape_val:.2f}%")

# Plot
plt.figure(figsize=(12,5))
plt.plot(test_merged['ds'], test_merged['y'], 'k.', label='Actual')
plt.plot(test_merged['ds'], test_merged['yhat'], 'b--', alpha=0.6, label='Prophet')
plt.plot(test_merged['ds'], test_merged['yhat_corrected'], 'g-', label='Corrected Forecast')
plt.legend()
plt.title("⚡ Unseen 48h Energy Demand Forecast")
plt.xlabel("Datetime")
plt.ylabel("Demand")
plt.grid(True)
plt.tight_layout()
plt.show()

# Export forecast to JSON
forecast_output = {
    'ds': test_merged['ds'].astype(str).tolist(),
    'y': test_merged['y'].tolist(),
    'yhat': test_merged['yhat'].tolist(),
    'yhat_corrected': test_merged['yhat_corrected'].tolist()
}
with open('../frontend/forecast.json', 'w') as f:
    json.dump(forecast_output, f)