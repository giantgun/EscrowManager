-include .env
run-tests:; forge test --fork-url $ETH_MAINNET_RPC_URL
setup-anvil-with-state:; anvil --fork-url "$(ETH_MAINNET_RPC_URL)" --chain-id 31337 --mnemonic "$(DEV_MNEMONIC)" --state state.json
deploy-escrow-manager:; forge script script/DeployEscrowManager.s.sol --broadcast --private-keys "$(DEV_PLATFORM_PRIVATE_KEY)" --rpc-url http://127.0.0.1:8545
setup-anvil:; anvil --fork-url "$(ETH_MAINNET_RPC_URL)" --chain-id 31337 --mnemonic "$(DEV_MNEMONIC)"