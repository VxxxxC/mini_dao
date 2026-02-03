<script lang="ts">
import { AppKit } from "$lib/stores/appkit";

let address: string = $derived("");
AppKit?.subscribeState(() => {
  address = AppKit?.getAccount()?.address ?? "Not connected";
});

</script>

<div class="text-5xl text-cyan-600">This is Home Page</div>
<button class="p-2 rounded-xl border-2 border-white bg-gray-700 text-white">
<appkit-button></appkit-button>
</button>

<div class="mt-4 text-lg">Connected Address: {address}</div>
