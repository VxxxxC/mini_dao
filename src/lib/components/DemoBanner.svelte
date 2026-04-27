<!-- DemoBanner.svelte
     Displays a dismissible warning banner that clearly labels the current governance
     settings as demonstration-only (shortened delays, hardcoded quorum). Should be
     rendered on every page that exposes governance parameters to the user.
-->
<script lang="ts">
	let dismissed = $state(false);
</script>

{#if !dismissed}
	<div
		class="flex w-full flex-row items-start justify-between gap-x-4 rounded-lg border border-amber-300 bg-amber-50 px-4 py-3 dark:border-amber-700 dark:bg-amber-950"
		role="alert"
	>
		<div class="flex flex-row items-start gap-x-3">
			<div class="space-y-2">
				<p class="text-sm font-semibold text-amber-800 dark:text-amber-300">
					🚨 Demonstration Only — Not a Real Governance Protocol
				</p>

				<!-- Workflow purpose -->
				<p class="text-xs text-amber-700 dark:text-amber-400">
					This app demonstrates the full DAO governance lifecycle: <strong>Claim tokens → Delegate
					→ Create proposal → Vote → Queue → Execute.</strong> It is deployed on the
					<strong>Sepolia testnet</strong> for demonstration purposes and is
					<strong>not connected to any real protocol or production system.</strong>
				</p>

				<!-- Execute disclaimer — kept red for emphasis -->
				<div
					class="rounded border border-red-300 bg-red-100 px-3 py-2 text-xs text-red-800 dark:border-red-700 dark:bg-red-900 dark:text-red-300"
				>
					⛔ <strong>Completing the full voting workflow has no real-world effect.</strong> No funds
					are moved, no external systems are affected, and no governance decisions carry any
					real-world consequence. This is purely a workflow demonstration.
				</div>

				<!-- Governance params grid -->
				<div
					class="tablet:grid-cols-4 grid grid-cols-2 gap-x-6 gap-y-0.5 text-xs text-amber-700 dark:text-amber-400"
				>
					<span>⏱ Voting delay: <strong>30 seconds</strong></span>
					<span>🗳 Voting period: <strong>1 minute</strong></span>
					<span>📊 Quorum: <strong>300 MDAO (≈ 3 wallets)</strong></span>
					<span>🔑 Min voting power: <strong>≥ 10 MDAO</strong></span>
				</div>
				<p class="text-xs text-amber-600 dark:text-amber-500">
					Governance parameters are intentionally shortened for demonstration purposes only.
				</p>
			</div>
		</div>

		<!-- dismiss button -->
		<button
			type="button"
			aria-label="Dismiss demo warning"
			onclick={() => (dismissed = true)}
			class="shrink-0 rounded p-0.5 text-amber-500 transition hover:bg-amber-100 dark:hover:bg-amber-900"
		>
			<svg
				class="h-4 w-4"
				fill="none"
				stroke="currentColor"
				stroke-width="2"
				viewBox="0 0 24 24"
				aria-hidden="true"
			>
				<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
			</svg>
		</button>
	</div>
{/if}
