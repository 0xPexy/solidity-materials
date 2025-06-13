# Foundry Review

A concise guide covering **why Foundry** stands out for Solidity development and **how to use** its core tools effectively.


## Part I: Why Foundry

### 1. Speed and Efficiency

* **Rust-based Compiler**: Delivers compilation speeds several times faster than JavaScript-based tools like Hardhat.
* **`forge build`**: Instantly compiles thousands of lines of contracts, minimizing wait times.

### 2. Integrated Testing Framework (Forge)

* **Native Solidity Unit Tests**: Write tests in Solidity, maintaining syntax consistency between contracts and tests.
* **Comprehensive Test Reports**: `forge test` outputs gas usage, stack traces, and assertion messages for rapid debugging.
* **Built-in Fuzzing**: Automatically explores input ranges to uncover edge-case bugs.

### 3. Lightweight Local Node (Anvil)

* **Rust-based Node**: Compatible with Ganache and Hardhat Network, optimized for speed and low resource usage.
* **Mainnet Forking**: Instantly fork mainnet state with `anvil --fork-url <RPC_URL>`.
* **Pre-funded Accounts & Snapshots**: Provides test accounts and persistent snapshots via `--state <FILE>`.

### 4. Utility CLI (Cast & Chisel)

* **Cast**: CLI for Ethereum JSON-RPC — craft transactions, query on-chain data, and automate workflows.
* **Chisel**: Interactive Solidity REPL for experimenting with small code snippets without full deployment.

### 5. Gas Snapshots & Regression Detection

* **`forge snapshot`**: Captures gas usage per function and flags regressions on subsequent runs.
* **CI Integration**: Embed snapshots in pipelines to prevent unintended gas cost increases.

### 6. Minimal Configuration & Modular Structure

* **One-step Installation**: `foundryup` installs the entire toolkit in one command.
* **Simple Project Setup**: Define structure via `forge.toml` without complex plugin loaders.

### 7. IDE Integration & Community

* **VSCode Support**: Seamless with Solidity plugins, enabling compile/test/debug shortcuts.
* **Active Ecosystem**: Official GitHub and Discord channels, plus rich open-source examples and templates.


## Part II: Usage

### Core Commands

#### Setup & Project Lifecycle

```bash
# Install or update Foundry suite
foundryup

# Initialize a new project
forge init <PROJECT_NAME>

# Compile contracts
forge build
```

#### Testing & Coverage

```bash
# Run all tests
forge test

# Test with mainnet fork
forge test --fork-url <RPC_URL>

# Generate coverage report
forge coverage
```

#### Scripting & Deployment

```bash
# Run and broadcast a deployment script
forge script <SCRIPT_PATH> --rpc-url <RPC_URL> --broadcast --private-key <KEY>

# Clone on-chain contract into project
forge clone <CONTRACT_ADDRESS>
```

#### Local Node Control (Anvil)

```bash
# Start an Anvil node
anvil

# Fork mainnet state
anvil --fork-url <RPC_URL>

# Save/load state snapshots
anvil --state <STATE_FILE>
```

#### RPC & Transactions (Cast)

```bash
# Query contract data
cast call <CONTRACT> <SIGNATURE> <ARGS> --rpc-url <RPC_URL>

# Send ETH or tokens
cast send <TO> --value <AMOUNT> --private-key <KEY>

# Check block number
cast block-number --rpc-url <RPC_URL>
```

#### Interactive REPL (Chisel)

```bash
# Start Solidity REPL
chisel

# In REPL:
> import "./src/MyContract.sol" as MC;
> MC.deploy();
> MC.myFunction(arg1, arg2);
```
