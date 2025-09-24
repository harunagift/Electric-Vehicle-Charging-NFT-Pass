# ⚡ Voltpass - Electric Vehicle Charging NFT Pass

A revolutionary blockchain-based solution for EV charging access management using NFT passes on the Stacks blockchain.

## 🚗 Overview

Voltpass enables seamless access to electric vehicle charging stations through NFT-based passes. Users can mint charging passes, add funds, access authorized stations, and track their charging sessions - all secured by smart contracts.

## ✨ Features

- 🎫 **NFT-Based Access**: Unique non-fungible tokens serve as charging passes
- ⚡ **Station Management**: Register and manage charging stations with operators
- 💰 **Prepaid Balance**: Add STX funds to passes for automated payments
- 🔐 **Access Control**: Grant specific station access to pass holders
- 📊 **Session Tracking**: Complete charging session history and analytics
- 🔄 **Real-time Billing**: Automatic cost calculation based on usage time
- 🔧 **Maintenance Tracking**: Schedule and track station maintenance with uptime monitoring
- 📈 **Reliability Scoring**: Real-time station reliability metrics and operator incentives

## 🛠 Usage

### Minting a Pass

```clarity
(contract-call? .Voltpass mint 'SP1234567890ABCDEF)
```

### Adding Funds

```clarity
(contract-call? .Voltpass add-funds u1 u1000000)
```

### Starting a Charging Session

```clarity
(contract-call? .Voltpass start-charging-session u1 u1)
```

### Ending a Charging Session

```clarity
(contract-call? .Voltpass end-charging-session u1 u1 u500)
```

### Scheduling Station Maintenance

```clarity
(contract-call? .Voltpass schedule-maintenance u1 u1000 u1100 "Routine" "Monthly safety inspection")
```

### Checking Station Reliability

```clarity
(contract-call? .Voltpass calculate-reliability u1)
```

## 📋 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `mint` | Create a new charging pass NFT |
| `transfer` | Transfer pass ownership |
| `add-funds` | Add STX balance to a pass |
| `register-station` | Register new charging station |
| `grant-station-access` | Grant station access to pass |
| `start-charging-session` | Begin charging session |
| `end-charging-session` | Complete charging session |
| `schedule-maintenance` | Schedule station maintenance window |
| `start-maintenance` | Begin scheduled maintenance |
| `complete-maintenance` | Complete maintenance and restore operation |
| `update-station-state` | Update station operational state |
| `claim-operator-incentive` | Claim reliability-based rewards |
| `deactivate-pass` | Deactivate a charging pass |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-charging-pass` | Get pass details |
| `get-charging-station` | Get station information |
| `get-session` | Get session details |
| `get-pass-balance` | Check pass balance |
| `has-station-access` | Verify station access |
| `get-station-status` | Get station operational status |
| `get-maintenance-record` | Get maintenance record details |
| `is-station-operational` | Check if station is available |
| `calculate-reliability` | Get station reliability score |
| `get-operator-incentives` | Check operator reward balance |

## 🏗 Data Structures

### Charging Pass
- Owner principal
- Station access list (up to 20 stations)
- STX balance
- Creation and expiration timestamps
- Active status

### Charging Station
- Operator principal
- Location description
- Rate per minute
- Active status
- Total sessions count

### Charging Session
- Station ID
- Start/end timestamps
- Energy consumed
- Cost calculation
- Active status

### Station Status
- Operational state (1=Operational, 2=Maintenance, 3=Offline)
- Last heartbeat timestamp
- Total uptime/downtime tracking
- Reliability score (0-100)
- Maintenance history count

### Maintenance Record
- Station ID and operator
- Scheduled vs actual start/end times
- Maintenance type and description
- Completion status

## 🔧 Development

### Prerequisites
- Clarinet CLI
- Stacks blockchain environment

### Testing

Run the contract checks:

```bash
clarinet check
```

Run integration tests:

```bash
clarinet test
```

### Deployment

Deploy to testnet:

```bash
clarinet deploy --testnet
```

## 🎯 Use Cases

- 🏢 **Corporate Fleets**: Manage company vehicle charging access
- 🏠 **Residential Communities**: Control private charging station usage  
- 🏪 **Commercial Networks**: Operate public charging infrastructure
- 🎫 **Subscription Services**: Offer premium charging memberships

## ⚙️ Configuration

The contract includes configurable parameters:

- **Pass Expiration**: Default 1 year (52,560 blocks)
- **Maximum Station Access**: 20 stations per pass
- **Maximum Sessions**: 50 sessions per pass
- **Maximum Stations per Operator**: 10 stations
- **Maximum Maintenance History**: 10 records per station
- **Default Reliability Threshold**: 85% for operator incentives

## 🔒 Security Features

- Owner-only administrative functions
- Pass ownership verification
- Station authorization checks
- Balance validation before charging
- Session state management

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Not token owner |
| u102 | Resource not found |
| u103 | Invalid station |
| u104 | Insufficient funds |
| u105 | Already exists |
| u106 | Session not active |
| u107 | Unauthorized station access |
| u110 | Station offline/maintenance |
| u111 | Invalid maintenance parameters |
| u112 | Maintenance already active |

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines and submit pull requests for improvements.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Built with ❤️ for the electric vehicle ecosystem*
