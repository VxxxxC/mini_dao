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
			<div class="space-y-1">
				<p class="text-sm font-semibold text-amber-800 dark:text-amber-300">
					⚠️ Demo / Local Configuration — Not for Production
				</p>
				<p class="text-xs text-amber-700 dark:text-amber-400">
					This deployment uses intentionally shortened governance parameters for demonstration
					purposes only. <strong>Do not deploy these settings to any public network.</strong>
				</p>
				<div
					class="tablet:grid-cols-4 mt-1.5 grid grid-cols-2 gap-x-6 gap-y-0.5 text-xs text-amber-700 dark:text-amber-400"
				>
					<span>⏱ Voting delay: <strong>30 seconds</strong></span>
					<span>🗳 Voting period: <strong>1 minute</strong></span>
					<span>📊 Quorum: <strong>300 MDAO (≈ 3 wallets)</strong></span>
					<span>🔑 Min voting power: <strong>≥ 10 MDAO</strong></span>
				</div>
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
