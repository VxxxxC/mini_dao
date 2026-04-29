import { render } from 'vitest-browser-svelte';
import { expect, test, describe } from 'vitest';
import { page } from 'vitest/browser';
import ProposalStatus from '$lib/components/ProposalStatus.svelte';
import { ProposalStatusEnum } from '$lib/types/ProposalCard.t';

// ---------------------------------------------------------------------------
// All 8 valid enum values with their expected labels and color classes
// ---------------------------------------------------------------------------
const STATUS_CASES = [
	{ status: ProposalStatusEnum.Pending,   label: 'Pending',   colorClass: 'text-yellow-500'  },
	{ status: ProposalStatusEnum.Active,    label: 'Active',    colorClass: 'text-indigo-500'  },
	{ status: ProposalStatusEnum.Canceled,  label: 'Canceled',  colorClass: 'text-gray-500'    },
	{ status: ProposalStatusEnum.Defeated,  label: 'Defeated',  colorClass: 'text-red-500'     },
	{ status: ProposalStatusEnum.Succeeded, label: 'Succeeded', colorClass: 'text-green-500'   },
	{ status: ProposalStatusEnum.Queued,    label: 'Queued',    colorClass: 'text-blue-500'    },
	{ status: ProposalStatusEnum.Expired,   label: 'Expired',   colorClass: 'text-orange-500'  },
	{ status: ProposalStatusEnum.Executed,  label: 'Executed',  colorClass: 'text-emerald-500' },
] as const;

// ---------------------------------------------------------------------------
// Label rendering
// ---------------------------------------------------------------------------
describe('ProposalStatus – label text', () => {
	for (const { status, label } of STATUS_CASES) {
		test(`renders "${label}" for status ${status}`, async () => {
			render(ProposalStatus, { status });
			await expect.element(page.getByText(label)).toBeInTheDocument();
		});
	}
});

// ---------------------------------------------------------------------------
// Color class applied to wrapper
// ---------------------------------------------------------------------------
describe('ProposalStatus – wrapper color class', () => {
	for (const { status, label, colorClass } of STATUS_CASES) {
		test(`wrapper has "${colorClass}" for ${label}`, async () => {
			render(ProposalStatus, { status });
			// The color class is on the outer <div>; innerHTML check is the most reliable
			expect(document.body.innerHTML).toContain(colorClass);
		});
	}
});

// ---------------------------------------------------------------------------
// Icon visibility toggle
// ---------------------------------------------------------------------------
describe('ProposalStatus – icon visibility', () => {
	test('renders an SVG icon by default', async () => {
		render(ProposalStatus, { status: ProposalStatusEnum.Active });
		await expect.element(page.getByText('Active')).toBeInTheDocument();
		expect(document.querySelectorAll('svg').length).toBeGreaterThan(0);
	});

	test('hides SVG icon when showIcon=false', async () => {
		render(ProposalStatus, { status: ProposalStatusEnum.Active, showIcon: false });
		await expect.element(page.getByText('Active')).toBeInTheDocument();
		expect(document.querySelectorAll('svg').length).toBe(0);
	});
});

// ---------------------------------------------------------------------------
// Fuzz – out-of-range enum values should hit the default branch
// ---------------------------------------------------------------------------
describe('ProposalStatus – fuzz: unknown status values', () => {
	const unknownValues = [8, 99, -1, 255, 1000];

	for (const val of unknownValues) {
		test(`renders "Unknown" for out-of-range value ${val}`, async () => {
			render(ProposalStatus, { status: val as ProposalStatusEnum });
			await expect.element(page.getByText('Unknown')).toBeInTheDocument();
		});
	}
});
