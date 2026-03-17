build:
	forge build --sizes
	$(MAKE) cp-abi

deploy-anvil-contract:
	forge script ./script/DeployDao.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

cp-abi:
	cp ./out/MiniDaoFaucet.sol/MiniDaoFaucet.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoGovernance.sol/MiniDaoGovernance.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoTimeLock.sol/MiniDaoTimeLock.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoToken.sol/MiniDaoToken.json ../src/lib/contracts_abi/
	cp ./out/MiniDaoVoteBox.sol/MiniDaoVoteBox.json ../src/lib/contracts_abi/
