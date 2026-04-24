build:
	forge build --sizes
	$(MAKE) cp-abi

deploy-anvil-contract:
	forge script ./script/DeployDao.s.sol --broadcast --rpc-url="http://localhost:8545" --private-key="0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6" # NOTE: Anvil 9 private key

deploy-sepolia-contract:
	forge script ./script/DeployDao.s.sol --broadcast --rpc-url="${VITE_SEPOLIA_API_RPC_URL}" --account="default_test_wallet"

cp-abi:
	cp ./out/MiniDaoFaucet.sol/MiniDaoFaucet.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoGovernance.sol/MiniDaoGovernance.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoTimeLock.sol/MiniDaoTimeLock.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoToken.sol/MiniDaoToken.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoVoteBox.sol/MiniDaoVoteBox.json ../src/lib/contracts_abi/
