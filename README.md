AI-Powered Decentralized Energy Marketplace System
Overview
This project combines a blockchain-based energy marketplace with AI-driven energy demand forecasting. It features:

A web frontend for user interaction.
A Solidity smart contract for secure energy trading.
A Python AI model for forecasting energy demand.

Project Structure
AIPoweredEnergyMarketplace/
├── frontend/
│   ├── index.html        # Webpage UI
│   ├── styles.css       # CSS styles
│   ├── script.js        # JavaScript logic
│   └── forecast.json    # AI forecast data
├── contracts/
│   └── Energy.sol       # Solidity smart contract
├── ai_model/
│   └── ai_model.py      # Python AI model
├── README.md            # Project documentation
├── structure.txt        # Project structure description
├── .gitignore          # Git ignore file
└── requirements.txt     # Python dependencies

Components

Frontend:

Built with HTML, CSS, JavaScript.
Features login, dashboard, analytics, and marketplace.
Uses Web3.js for blockchain interaction and Chart.js for visualizations.


Smart Contract:

Energy.sol: Manages energy listings, purchases, and withdrawals.
Uses OpenZeppelin for security.


AI Model:

ai_model.py: Uses Prophet and XGBoost for 48-hour energy demand forecasting.
Exports forecasts to forecast.json.



Setup Instructions
Prerequisites

VS Code: Install from code.visualstudio.com.
Extensions: Install Live Server, Prettier, Solidity, Python.
Node.js: For frontend and contract deployment.
Python 3.8+: For AI model.
Remix IDE: For contract compilation/deployment.
MetaMask: For blockchain interaction.

Steps

Frontend:

Create frontend folder and add index.html, styles.css, script.js.
Open index.html with Live Server to test.
Test login (demo@energy.com, demo123) and wallet connection.


Smart Contract:

Open Energy.sol in Remix IDE (remix.ethereum.org).
Compile with Solidity ^0.8.17.
Deploy to a testnet (e.g., Sepolia) and update script.js with contract address and ABI.
Install OpenZeppelin:npm install @openzeppelin/contracts




AI Model:

Create ai_model folder and add ai_model.py.
Install dependencies:pip install -r requirements.txt


Place energy data (CSV/Excel) in EnergyData/ folder.
Run ai_model.py to generate frontend/forecast.json.



Running the Project

Frontend:

Open frontend/index.html with Live Server.
Test login, wallet connection, listing/buying energy, and charts.


Smart Contract:

Deploy via Remix and test functions (listEnergy, buyEnergy, withdraw).
Verify seller status before listing.


AI Model:

Run ai_model.py to generate forecasts and forecast.json.
Check plots and accuracy metrics.



Next Steps

Deploy frontend to Netlify/Vercel.
Deploy smart contract to a mainnet.
Add user authentication and advanced analytics.

License
MIT License
