-include .env
run-tests:; forge test --fork-url "$(ETH_MAINNET_RPC_URL)"
setup-anvil-with-state:; anvil --fork-url "$(ETH_MAINNET_RPC_URL)" --chain-id 31337 --mnemonic "$(DEV_MNEMONIC)" --state state.json --no-rate-limit
deploy-escrow-manager:; forge script script/DeployEscrowManager.s.sol --broadcast --private-keys "$(DEV_PLATFORM_PRIVATE_KEY)" --rpc-url http://127.0.0.1:8545
setup-anvil:; anvil --fork-url "$(ETH_MAINNET_RPC_URL)" --chain-id 31337 --mnemonic "$(DEV_MNEMONIC)" --no-rate-limit
run-test-coverage:;  forge coverage --fork-url "$(ETH_MAINNET_RPC_URL)"

impersonate-whale:
	cast rpc anvil_impersonateAccount "$(DEV_WHALE)"

fund-dev-accounts: impersonate-whale
	cast send "$(MNEE_ADDRESS)" "transfer(address,uint256)" "$(DEV_BUYER_PUBLIC_KEY)" 1000e18 --from "$(DEV_WHALE)" --unlocked
	cast rpc anvil_stopImpersonatingAccount "$(DEV_WHALE)"

setup-env-wsl:
	sudo apt install dos2unix
	dos2unix .env
	export $(cat .env | xargs)

load-env:
	export $(cat .env | xargs)

deploy-to-testnet: load-env
	forge script script/DeployEscrowManager.s.sol --tc DeployEscrowManagerToTestnet  --rpc-url "$(SEPOLIA_RPC_URL)" --broadcast --account "$(SECURE_WALLET_NAME)" --sender "$(SECURE_WALLET_PUBLIC_ADDRESS)"

deploy-to-mainnet: load-env
	forge script script/DeployEscrowManager.s.sol --tc DeployEscrowManager --rpc-url "$(ETH_MAINNET_RPC_URL)" --broadcast --account "$(SECURE_WALLET_NAME)" --sender "$(SECURE_WALLET_PUBLIC_ADDRESS)"
