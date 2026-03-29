export const customImport = [
	// NOTE: Type Import
	/* {
		from: '$lib/components/Breakpoint.svelte',
		imports: ['breakpoint'],
		type: true
	} */

	// NOTE: Package Import
	{
		'$lib/components/Breakpoint.svelte': ['breakpoint'],
		'$lib/config/contractAddress.ts': ['Address', 'ChainId'],
		
	}
];
