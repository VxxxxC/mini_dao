<script lang="ts">
    import { page } from '$app/state';
	import { walletStatus } from '$lib/components/WalletStore.svelte';
    import { readContract, writeContract, waitForTransactionReceipt } from '@wagmi/core';
    import { wagmiConfig } from '$lib/config/appKitConfig';
    import  MiniDaoFaucet  from '$lib/contracts_abi/MiniDaoFaucet.json';

	let activeUrl = $derived(page.url.pathname);
	let address: string = $derived(walletStatus.address);
	let status: string = $derived(walletStatus.status);
    let hasClaimed: boolean = $derived(false);
    let isClaiming: boolean = $derived(false);
    let isLoadingStatus: boolean = $derived(false);

    const CHAIN_ID = 31337; // Hardhat Local Network
    const FAUCET_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0';

    $effect(() =>{
        if(status === 'connected') {
            checkClaimStatus(address);
        } else {
            hasClaimed = false;
        }
    })

async function checkClaimStatus(address: string) {
    try {
      isLoadingStatus = true;
      // 呼叫 Smart Contract 嘅 mapping: hasClaimedFaucet(address)
      const result = await readContract(wagmiConfig, {
        address: FAUCET_ADDRESS,
        abi: MiniDaoFaucet.abi,
        functionName: 'hasClaimed',
        args: [address]
      });
      
      hasClaimed = result as boolean;
      console.log(`Address ${address} claimed status:`, hasClaimed);
    } catch (error) {
      console.error("Loading Faucet status failed :", error);
    } finally {
      isLoadingStatus = false;
    }
  }

  async function handleClaim() {
    if (status !== 'connected') return alert("Please connect your wallet first!");
    
    try {
      isClaiming = true;

      const hash = await writeContract(wagmiConfig, {
        address: FAUCET_ADDRESS,
        abi: MiniDaoFaucet.abi,
        functionName: 'claim',
        chainId: CHAIN_ID
      });

      console.log("Transaction sent:", hash);

      const receipt = await waitForTransactionReceipt(wagmiConfig, { hash });
      
      if (receipt.status === 'success') {
        hasClaimed = true;
        alert("Successfully claimed 100 MDAO! Please go to Delegate to activate your voting power!");
      }
    } catch (error) {
      console.error("Claim failed:", error);
    } finally {
      isClaiming = false;
    }
  }
</script>

<div class="p-6 bg-white rounded-2xl shadow-sm border border-gray-100 text-center">
  <h2 class="text-xl font-bold mb-2">💰 Mini DAO Faucet</h2>
  <p class="text-gray-500 mb-6">Each person can claim 100 MDAO for governance voting</p>

  {#if status !== 'connected'}
    <button disabled class="w-full py-3 px-4 bg-gray-200 text-gray-500 font-bold rounded-xl cursor-not-allowed">
      Please connect your wallet first
    </button>
    
  {:else if isLoadingStatus}
    <button disabled class="w-full py-3 px-4 bg-blue-100 text-blue-500 font-bold rounded-xl animate-pulse">
      Checking eligibility...
    </button>
    
  {:else if hasClaimed}
    <button disabled class="w-full py-3 px-4 bg-green-100 text-green-700 font-bold rounded-xl flex items-center justify-center gap-2">
      <span>✅</span> Already claimed
    </button>
    
  {:else}
    <button 
      onclick={handleClaim} 
      disabled={isClaiming}
      class="w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-xl transition-colors disabled:opacity-50 disabled:cursor-wait"
    >
      {#if isClaiming}
        Processing transaction... (please confirm in your wallet)
      {:else}
        Claim 100 MDAO
      {/if}
    </button>
  {/if}
</div>