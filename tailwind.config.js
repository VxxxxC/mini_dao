import * as flowbiteSvelte from 'flowbite-svelte';

const config = {
	content: [
		'./src/**/*.{html,js,svelte,ts}',
		'./node_modules/flowbite-svelte/**/*.{html,js,svelte,ts}'
	],

	plugins: [flowbiteSvelte],

	darkMode: 'class',

	theme: {
		extend: {
			colors: {}
		}
	}
};

module.exports = config;
